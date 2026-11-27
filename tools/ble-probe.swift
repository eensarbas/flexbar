// ble-probe: send raw frames to the JBL Tune Flex 2 over BLE and print every notification.
// Development tool for working out commands; not part of the app.
//
// Build (macOS needs a Bluetooth usage description, so it runs as a tiny .app bundle):
//   ./tools/build-probe.sh
// Run, frames as hex, sent 1.5 s apart:
//   open -n -W --stdout /tmp/probe.txt tools/build/BLEProbe.app --args AA910111 AA800101
//   cat /tmp/probe.txt
//
// Only send read requests unless you know what a write does and how to undo it.
// Never write to the OTA characteristics (86868686-… / 97979797-…).
import CoreBluetooth
import Foundation

let SVC = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0000")
let TX = CBUUID(string: "65786365-6c70-6f69-6e74-2e636f6d0002")
let frames: [Data] = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-") }.map { s in
    Data(stride(from: 0, to: s.count, by: 2).map { i in
        UInt8(s[s.index(s.startIndex, offsetBy: i)..<s.index(s.startIndex, offsetBy: i + 2)], radix: 16)!
    })
}
func hex(_ d: Data) -> String { d.map { String(format: "%02X", $0) }.joined(separator: " ") }
setvbuf(stdout, nil, _IOLBF, 0)

final class Probe: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var cm: CBCentralManager!
    var p: CBPeripheral?
    var tx: CBCharacteristic?

    override init() { super.init(); cm = CBCentralManager(delegate: self, queue: nil) }

    func centralManagerDidUpdateState(_ c: CBCentralManager) {
        guard c.state == .poweredOn else { print("bluetooth state", c.state.rawValue); return }
        if let known = c.retrieveConnectedPeripherals(withServices: [SVC]).first { use(known) }
        else { c.scanForPeripherals(withServices: nil, options: nil) }
    }

    func centralManager(_ c: CBCentralManager, didDiscover per: CBPeripheral,
                        advertisementData a: [String: Any], rssi: NSNumber) {
        let name = per.name ?? (a[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        guard name.hasPrefix("JBL Tune Flex 2") else { return }
        c.stopScan()
        use(per)
    }

    func use(_ per: CBPeripheral) { p = per; per.delegate = self; cm.connect(per) }

    func centralManager(_ c: CBCentralManager, didConnect per: CBPeripheral) {
        print("connected", per.name ?? "")
        per.discoverServices([SVC])
    }

    func peripheral(_ per: CBPeripheral, didDiscoverServices e: Error?) {
        for s in per.services ?? [] { per.discoverCharacteristics(nil, for: s) }
    }

    func peripheral(_ per: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error e: Error?) {
        for ch in s.characteristics ?? [] {
            if ch.properties.contains(.notify) { per.setNotifyValue(true, for: ch) }
            if ch.uuid == TX { tx = ch }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.send() }
    }

    func send() {
        guard let p, let tx else { print("no tx characteristic"); return }
        let type: CBCharacteristicWriteType = tx.properties.contains(.write) ? .withResponse : .withoutResponse
        for (i, f) in frames.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.5) {
                print("  ->", hex(f))
                p.writeValue(f, for: tx, type: type)
            }
        }
    }

    func peripheral(_ per: CBPeripheral, didUpdateValueFor ch: CBCharacteristic, error e: Error?) {
        print("  <-", hex(ch.value ?? Data()))
    }
}

let probe = Probe()
RunLoop.main.run(until: Date().addingTimeInterval(Double(frames.count) * 1.5 + 12))
if let p = probe.p { probe.cm.cancelPeripheralConnection(p) }
