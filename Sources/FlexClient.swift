import CoreBluetooth
import Foundation

/// Noise-control modes of the JBL Tune Flex 2 and the BLE frames that select them.
/// Frames come from the JBL Headphones app (CmdGen.genSetANCModes / genSetANCModeOFF)
/// and were confirmed on real hardware.
enum NoiseMode: Int, CaseIterable, Identifiable {
    case anc, ambient, talkThru, off

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .anc: return String(localized: "Noise Cancelling")
        case .ambient: return String(localized: "Ambient Aware")
        case .talkThru: return String(localized: "TalkThru")
        case .off: return String(localized: "Off")
        }
    }

    var symbol: String {
        switch self {
        case .anc: return "waveform.slash"
        case .ambient: return "ear"
        case .talkThru: return "person.wave.2"
        case .off: return "headphones"
        }
    }

    /// Name used by the flexbar:// URL scheme.
    var urlName: String {
        switch self {
        case .anc: return "anc"
        case .ambient: return "ambient"
        case .talkThru: return "talkthru"
        case .off: return "off"
        }
    }

    var command: [UInt8] {
        switch self {
        case .anc: return [0xAA, 0x91, 0x07, 0x10, 0x01, 0x01, 0x02, 0x00, 0x03, 0x00]
        case .ambient: return [0xAA, 0x91, 0x07, 0x10, 0x01, 0x00, 0x02, 0x01, 0x03, 0x00]
        case .talkThru: return [0xAA, 0x91, 0x07, 0x10, 0x01, 0x00, 0x02, 0x00, 0x03, 0x01]
        case .off: return [0xAA, 0x91, 0x01, 0x13]
        }
    }
}

struct BatteryLevel: Equatable {
    var percent: Int
    /// First byte of the 2-byte battery value; the JBL app stores it as the charging flag.
    var charging: Bool
}

/// Talks to a JBL Tune Flex 2 over its Harman/BES GATT command service.
///
/// Protocol summary (see docs/PROTOCOL.md):
/// - service 65786365-6c70-6f69-6e74-2e636f6d0000, write to ...0002, notifications on ...0001
/// - short frames:   AA <cmd> <len> <payload>
/// - feature frames: AA 06 <len LE16> <type> (<id BE16> <len> <value>)...
final class FlexClient: NSObject, ObservableObject {
    enum State: Equatable {
        case bluetoothOff
        case unauthorized
        case searching
        case connecting
        case connected
    }

    @Published private(set) var state: State = .searching
    @Published private(set) var mode: NoiseMode?
    @Published private(set) var pendingMode: NoiseMode?
    @Published private(set) var left: BatteryLevel?
    @Published private(set) var right: BatteryLevel?
    @Published private(set) var caseLevel: BatteryLevel?
    @Published private(set) var firmware: String?
    @Published private(set) var deviceName = "JBL Tune Flex 2"
    @Published private(set) var lastError: String?
    /// Adaptive noise cancelling (only applies in Noise Cancelling mode).
    @Published private(set) var adaptiveANC: Bool?
    /// Ambient Aware strength, 0...6 (only applies in Ambient Aware mode).
    @Published private(set) var ambientLevel: Int?
    /// EQ category the earbuds report: 0...3 are FlexBar's presets; other values were set elsewhere (JBL app).
    @Published private(set) var eqCategory: UInt8?
    @Published private(set) var smartAV: SmartAVMode?
    @Published private(set) var beeping = BeepState()
    /// When Smart Audio & Video was last changed. The earbuds reconnect to apply a new profile
    /// (the JBL app waits up to 30 s for this too), so the UI treats that reconnect differently.
    @Published private(set) var smartAVChangedAt: Date?

    /// The case has no radio: the earbuds relay its battery only while they sit in it, and keep the last value
    /// once they leave. Charging earbuds are in the case, so without that the case value is probably stale.
    /// (Earbuds that are full may stop charging while still in the case; then this reports stale too.)
    var caseLevelIsStale: Bool {
        caseLevel != nil && left?.charging != true && right?.charging != true
    }

    /// True while the earbuds are likely reconnecting because of a Smart Audio & Video change.
    var isApplyingSmartAV: Bool {
        smartAVChangedAt.map { Date().timeIntervalSince($0) < 30 } ?? false
    }

    static let serviceUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0000")
    static let txUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0002")
    static let rxUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0001")
    static let namePrefix = "JBL Tune Flex 2"

    private static let queryMode: [UInt8] = [0xAA, 0x91, 0x01, 0x11]
    private static let queryAdvancedANC: [UInt8] = [0xAA, 0x91, 0x01, 0x21]
    private static let querySmartAV: [UInt8] = [0xAA, 0x80, 0x01, 0x01]
    private static let queryBeeping: [UInt8] = [0xAA, 0x23, 0x01, 0x01]
    private static let queryEQ: [UInt8] = [0xAA, 0xA2, 0x02, 0x01, 0xFF]        // current EQ
    private static let queryDesignEQ: [UInt8] = [0xAA, 0xA2, 0x02, 0x01, 0xCA]  // the earbuds' own tuning (202)
    // Features 0x1A (left), 0x1B (right), 0x1C (case), 0x05 (firmware).
    private static let queryStatus: [UInt8] = [0xAA, 0x06, 0x09, 0x00, 0x01, 0x00, 0x1A, 0x00, 0x1B, 0x00, 0x1C, 0x00, 0x05]

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var tx: CBCharacteristic?
    private var buffer: [UInt8] = []
    private var statusTimer: Timer?
    private var pendingTimeout: DispatchWorkItem?
    /// The earbuds' own tuning, needed to compute the EQ calibration.
    private var designEQ: [EQFilter]?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Public

    func setMode(_ newMode: NoiseMode) {
        guard state == .connected, let peripheral, let tx else {
            lastError = String(localized: "Headphones aren't connected.")
            return
        }
        lastError = nil
        pendingMode = newMode
        write(newMode.command, to: peripheral, tx)

        pendingTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.pendingMode == newMode else { return }
            self.pendingMode = nil
            self.lastError = String(localized: "The headphones didn't confirm the mode change.")
        }
        pendingTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)
    }

    /// Cycles ANC -> Ambient Aware -> TalkThru -> Off -> ANC.
    func cycleMode() {
        let order = NoiseMode.allCases
        let current = pendingMode ?? mode ?? .off
        let next = order[(order.firstIndex(of: current)! + 1) % order.count]
        setMode(next)
    }

    func refresh() {
        guard state == .connected, let peripheral, let tx else { return }
        var queries = [Self.queryMode, Self.queryAdvancedANC, Self.queryStatus, Self.querySmartAV, Self.queryBeeping, Self.queryEQ]
        if designEQ == nil { queries.append(Self.queryDesignEQ) }
        for query in queries {
            write(query, to: peripheral, tx)
        }
    }

    // The settings below show only what the earbuds report back, never an optimistic value:
    // each command makes the earbuds push their new state, which updates the published property.

    func setAdaptiveANC(_ on: Bool) { send([0xAA, 0x91, 0x03, 0x20, 0x01, on ? 1 : 0]) }

    func setAmbientLevel(_ level: Int) {
        guard ambientLevelRange.contains(level) else { return }
        send([0xAA, 0x91, 0x03, 0x20, 0xA1, UInt8(level)])
    }

    func setEQ(_ preset: EQPreset) { send(preset.command(design: designEQ ?? EQMath.fallbackDesign)) }

    func setSmartAV(_ mode: SmartAVMode) {
        smartAVChangedAt = Date()
        send(mode.command)
    }

    /// Starts or stops the beep on each earbud; nil leaves that side as it is.
    func beep(left: Bool?, right: Bool?) { send(BeepState.command(left: left, right: right)) }

    private func send(_ bytes: [UInt8]) {
        guard state == .connected, let peripheral, let tx else {
            lastError = String(localized: "Headphones aren't connected.")
            return
        }
        lastError = nil
        write(bytes, to: peripheral, tx)
    }

    // MARK: - Connection

    /// Scans by name every time. The headphones' BLE address rotates, so a saved peripheral
    /// identifier goes stale and a pending connect to it never completes.
    private func startConnecting() {
        guard central.state == .poweredOn else { return }
        if let connected = central.retrieveConnectedPeripherals(withServices: [Self.serviceUUID]).first {
            connect(connected)
            return
        }
        state = .searching
        central.scanForPeripherals(withServices: nil, options: nil)
    }

    private func connect(_ p: CBPeripheral) {
        peripheral = p
        p.delegate = self
        state = .connecting
        central.connect(p, options: nil)
    }

    private func resetDeviceState() {
        statusTimer?.invalidate()
        statusTimer = nil
        pendingTimeout?.cancel()
        tx = nil
        buffer = []
        mode = nil
        pendingMode = nil
        adaptiveANC = nil
        ambientLevel = nil
        eqCategory = nil
        designEQ = nil
        smartAV = nil
        beeping = BeepState()
        left = nil
        right = nil
        caseLevel = nil
    }

    private func write(_ bytes: [UInt8], to p: CBPeripheral, _ ch: CBCharacteristic) {
        let type: CBCharacteristicWriteType = ch.properties.contains(.write) ? .withResponse : .withoutResponse
        p.writeValue(Data(bytes), for: ch, type: type)
    }

    // MARK: - Parsing

    private func receive(_ data: Data) {
        buffer += data
        while buffer.count >= 3 {
            guard buffer[0] == 0xAA else { buffer.removeAll(); return }
            let total: Int
            if buffer[1] == 0x06 || buffer[1] == 0xA2 {  // these two use a 2-byte length
                guard buffer.count >= 4 else { return }
                total = 4 + (Int(buffer[2]) | Int(buffer[3]) << 8)
            } else {
                total = 3 + Int(buffer[2])
            }
            guard buffer.count >= total else { return }
            let frame = Array(buffer[0..<total])
            buffer.removeFirst(total)
            parse(frame)
        }
    }

    private func parse(_ f: [UInt8]) {
        switch f[1] {
        case 0x91 where f.count >= 4 && f[3] == 0x12:
            parseMode(f)
        case 0x91 where f.count >= 4 && f[3] == 0x22:
            parseAdvancedANC(f)
        case 0x80 where f.count >= 10 && f[3] == 0x02:
            // AA 80 09 02 <aac LE16> <sbc LE16> <latency LE16> <latency2 LE16>
            let u16 = { (i: Int) in UInt16(f[i]) | UInt16(f[i + 1]) << 8 }
            smartAV = SmartAVMode(aac: u16(4), sbc: u16(6), latency: u16(8))
        case 0xA2 where f.count >= 6 && (f[4] == 0x02 || f[4] == 0x04):
            parseEQ(f)
        case 0x23 where f.count >= 6 && f[3] == 0x02:
            // AA 23 03 02 <left> <right>, 1 = beeping
            beeping = BeepState(left: f[4] == 1, right: f[5] == 1)
        case 0x06 where f.count >= 5 && f[4] == 0x02:
            parseFeatures(f)
        case 0x12 where f.count > 3:
            // Device info pushed on connect; starts with the model name, NUL-terminated.
            let nameBytes = f[3...].prefix { $0 != 0 }
            if let name = String(bytes: nameBytes, encoding: .utf8), !name.isEmpty { deviceName = name }
        default:
            break
        }
    }

    /// AA 91 07 12 (<mode> <on>)... with mode 1 = ANC, 2 = Ambient Aware, 3 = TalkThru.
    private func parseMode(_ f: [UInt8]) {
        var active = NoiseMode.off
        var i = 4
        while i + 1 < f.count {
            if f[i + 1] == 1 {
                switch f[i] {
                case 1: active = .anc
                case 2: active = .ambient
                case 3: active = .talkThru
                default: break
                }
            }
            i += 2
        }
        mode = active
        if pendingMode == active {
            pendingMode = nil
            pendingTimeout?.cancel()
        }
    }

    /// AA A2 <len LE16> <02 | 04 (Q × 10)> <category> <calibration f32> <rate> <gains f32 ×2> <count>
    ///   then per band: <type> <gain f32> <frequency f32> <Q>
    private func parseEQ(_ f: [UInt8]) {
        let category = f[5]
        if category == 202 {
            guard f.count >= 20 else { return }
            let count = Int(f[19]), qScale = f[4] == 0x04 ? 10.0 : 1.0
            func f32(_ i: Int) -> Double {
                Double(Float(bitPattern: UInt32(f[i]) | UInt32(f[i + 1]) << 8 | UInt32(f[i + 2]) << 16 | UInt32(f[i + 3]) << 24))
            }
            var filters: [EQFilter] = []
            for n in 0..<count {
                let o = 20 + n * 10
                guard o + 10 <= f.count else { return }
                filters.append(EQFilter(type: f[o], gain: f32(o + 1), frequency: f32(o + 5), q: Double(f[o + 9]) / qScale))
            }
            if !filters.isEmpty { designEQ = filters }
        } else if category < 200 || category == 230 {
            eqCategory = category
        }
    }

    /// AA 91 <len> 22 (<key> <value>)...: 01 adaptive ANC on/off, A1 Ambient Aware level.
    private func parseAdvancedANC(_ f: [UInt8]) {
        var i = 4
        while i + 1 < f.count {
            switch f[i] {
            case 0x01: adaptiveANC = f[i + 1] == 1
            case 0xA1: ambientLevel = Int(f[i + 1])
            default: break
            }
            i += 2
        }
    }

    /// AA 06 <len LE16> 02 (<id BE16> <len> <value>)...
    private func parseFeatures(_ f: [UInt8]) {
        var i = 5
        while i + 3 <= f.count {
            let id = Int(f[i]) << 8 | Int(f[i + 1])
            let len = Int(f[i + 2])
            let start = i + 3
            guard start + len <= f.count else { break }
            let value = Array(f[start..<start + len])
            i = start + len

            switch id {
            case 0x1A: left = battery(value)
            case 0x1B: right = battery(value)
            case 0x1C: caseLevel = battery(value)
            case 0x05 where !value.isEmpty: firmware = value.map(String.init).joined(separator: ".")
            default: break
            }
        }
    }

    private func battery(_ value: [UInt8]) -> BatteryLevel? {
        guard let percent = value.last, percent <= 100 else { return nil }
        return BatteryLevel(percent: Int(percent), charging: value.count > 1 && value[0] != 0)
    }
}

// MARK: - CBCentralManagerDelegate

extension FlexClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startConnecting()
        case .unauthorized:
            resetDeviceState()
            state = .unauthorized
        default:
            resetDeviceState()
            state = .bluetoothOff
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover p: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        guard name.hasPrefix(Self.namePrefix) else { return }
        central.stopScan()
        connect(p)
    }

    func centralManager(_ central: CBCentralManager, didConnect p: CBPeripheral) {
        p.discoverServices([Self.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        resetDeviceState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.startConnecting() }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        resetDeviceState()
        startConnecting()  // scans until the headphones come back
    }
}

// MARK: - CBPeripheralDelegate

extension FlexClient: CBPeripheralDelegate {
    func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = p.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
            lastError = String(localized: "Control service not found.")
            central.cancelPeripheralConnection(p)
            return
        }
        p.discoverCharacteristics([Self.txUUID, Self.rxUUID], for: service)
    }

    func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for ch in service.characteristics ?? [] {
            if ch.uuid == Self.txUUID { tx = ch }
            if ch.uuid == Self.rxUUID { p.setNotifyValue(true, for: ch) }
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateNotificationStateFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == Self.rxUUID, ch.isNotifying, tx != nil else { return }
        state = .connected
        lastError = nil
        refresh()
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func peripheral(_ p: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error: Error?) {
        guard ch.uuid == Self.rxUUID, let value = ch.value else { return }
        receive(value)
    }
}
