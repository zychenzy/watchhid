#!/usr/bin/env swift
import Foundation
import CoreBluetooth

final class Scanner: NSObject, CBCentralManagerDelegate {
    private var central: CBCentralManager!
    private var found = Set<UUID>()

    func start() {
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            fputs("central state=\(central.state.rawValue)\n", stderr)
            if central.state == .unauthorized || central.state == .poweredOff {
                exit(1)
            }
            return
        }
        print("scanning… (Ctrl+C to stop)")
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false,
        ])
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? ""
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let uuids = services.map(\.uuidString)
        let hit = name.localizedCaseInsensitiveContains("Watch Mouse")
            || uuids.contains { $0.uppercased().contains("1812") }
        guard hit || ProcessInfo.processInfo.arguments.contains("--all") else { return }
        if found.insert(peripheral.identifier).inserted || hit {
            let appearance = advertisementData["kCBAdvDataAppearance"] as? NSNumber
            let appStr = appearance.map { String(format: "0x%04X", $0.intValue) } ?? "-"
            print("FOUND name=\(name.isEmpty ? "(none)" : name) rssi=\(RSSI) appearance=\(appStr) services=\(uuids) id=\(peripheral.identifier)")
        }
    }
}

let scanner = Scanner()
scanner.start()
RunLoop.main.run()
