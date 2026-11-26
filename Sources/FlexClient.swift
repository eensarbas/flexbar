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
    /// First byte of the 2-byte battery value. Assumed to be a charging flag; not verified yet.
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

    static let serviceUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0000")
    static let txUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0002")
    static let rxUUID = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0001")
    static let namePrefix = "JBL Tune Flex 2"

    private static let queryMode: [UInt8] = [0xAA, 0x91, 0x01, 0x11]
    // Features 0x1A (left), 0x1B (right), 0x1C (case), 0x05 (firmware).
    private static let queryStatus: [UInt8] = [0xAA, 0x06, 0x09, 0x00, 0x01, 0x00, 0x1A, 0x00, 0x1B, 0x00, 0x1C, 0x00, 0x05]

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var tx: CBCharacteristic?
    private var buffer: [UInt8] = []
    private var statusTimer: Timer?
    private var pendingTimeout: DispatchWorkItem?

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
        write(Self.queryMode, to: peripheral, tx)
        write(Self.queryStatus, to: peripheral, tx)
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
            if buffer[1] == 0x06 {
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
