#!/usr/bin/env swift
import Foundation
import CoreBluetooth

final class Scanner: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private var central: CBCentralManager!
    private var found = Set<UUID>()
    private var connectedTarget: CBPeripheral?
    private var readQueue: [CBCharacteristic] = []
    private var reading: CBCharacteristic?
    private var reportToSubscribe: CBCharacteristic?

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
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--target-id=") }),
           let identifier = UUID(uuidString: String(argument.dropFirst("--target-id=".count))),
           let target = central.retrievePeripherals(withIdentifiers: [identifier]).first {
            connectedTarget = target
            target.delegate = self
            print("RETRIEVED known target=\(target.identifier); connection does not prove advertising")
            central.connect(target)
        }
        print("scanning… (Ctrl+C to stop)")
        let filter = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--service=") })?
            .components(separatedBy: "=").last
        print("service filter=\(filter ?? "none")")
        central.scanForPeripherals(withServices: filter.map { [CBUUID(string: $0)] }, options: [
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
        if ProcessInfo.processInfo.arguments.contains("--connect"), name == "Watch Mouse", connectedTarget == nil {
            connectedTarget = peripheral
            peripheral.delegate = self
            print("CONNECT target=\(peripheral.identifier)")
            central.connect(peripheral)
        }
        if found.insert(peripheral.identifier).inserted || hit {
            let appearance = advertisementData["kCBAdvDataAppearance"] as? NSNumber
            let appStr = appearance.map { String(format: "0x%04X", $0.intValue) } ?? "-"
            print("FOUND name=\(name.isEmpty ? "(none)" : name) rssi=\(RSSI) appearance=\(appStr) services=\(uuids) id=\(peripheral.identifier)")
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("CONNECTED target=\(peripheral.identifier)")
        peripheral.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("CONNECT FAILED \(String(describing: error))")
    }
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        print("SERVICES CHANGED \(invalidatedServices.map { $0.uuid.uuidString })")
        readQueue.removeAll()
        reading = nil
        reportToSubscribe = nil
        peripheral.discoverServices(nil)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("GATT SERVICES \(peripheral.services?.map { $0.uuid.uuidString } ?? []) error=\(String(describing: error))")
        for service in peripheral.services ?? [] { print("GATT UUID uuid=\(service.uuid) bytes=\(service.uuid.data.count) hex=\(service.uuid.data.map { String(format: "%02X", $0) }.joined())") }
        for service in peripheral.services ?? [] { peripheral.discoverCharacteristics(nil, for: service) }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        print("GATT CHARACTERISTICS service=\(service.uuid) values=\(service.characteristics?.map { $0.uuid.uuidString } ?? []) error=\(String(describing: error))")
        for characteristic in service.characteristics ?? [] {
            print("GATT CHAR uuid=\(characteristic.uuid) bytes=\(characteristic.uuid.data.count) properties=\(characteristic.properties.rawValue)")
            if service.uuid == CBUUID(string: "1812") { peripheral.discoverDescriptors(for: characteristic) }
        }
        for characteristic in service.characteristics ?? [] where characteristic.uuid.uuidString == "2A4D" {
            if (service.uuid.uuidString.hasPrefix("A7B10001-7E42-4C63-9D17-B5A0F055C90") || service.uuid == CBUUID(string: "1812")) {
                reportToSubscribe = characteristic
            }
        }
        for characteristic in service.characteristics ?? [] where characteristic.properties.contains(.read) {
            if (service.uuid.uuidString.hasPrefix("A7B10001-7E42-4C63-9D17-B5A0F055C90") || service.uuid == CBUUID(string: "1812")) { readQueue.append(characteristic) }
        }
        readNext(peripheral)
    }
    private func readNext(_ peripheral: CBPeripheral) {
        guard reading == nil else { return }
        if !readQueue.isEmpty {
            let characteristic = readQueue.removeFirst()
            reading = characteristic
            peripheral.readValue(for: characteristic)
        } else if !ProcessInfo.processInfo.arguments.contains("--no-notify"), let report = reportToSubscribe {
            reportToSubscribe = nil
            peripheral.setNotifyValue(true, for: report)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("DESCRIPTORS char=\(characteristic.uuid) values=\(characteristic.descriptors?.map { $0.uuid.uuidString } ?? []) error=\(String(describing: error))")
        for descriptor in characteristic.descriptors ?? [] where descriptor.uuid == CBUUID(string: "2908") { peripheral.readValue(for: descriptor) }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        print("DESCRIPTOR VALUE uuid=\(descriptor.uuid) value=\(String(describing: descriptor.value)) error=\(String(describing: error))")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("GATT NOTIFY \(characteristic.uuid) active=\(characteristic.isNotifying) error=\(String(describing: error))")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("GATT VALUE \(characteristic.uuid) data=\(characteristic.value?.map { String(format: "%02X", $0) }.joined() ?? "nil") error=\(String(describing: error))")
        if reading === characteristic {
            reading = nil
            readNext(peripheral)
        }
    }

}

let scanner = Scanner()
scanner.start()
RunLoop.main.run()
