import Foundation
import CoreBluetooth
import Combine

struct ScannedPeripheral: Identifiable, Hashable {
    let id: UUID
    var name: String
    var rssi: Int
    var serviceUUIDs: [String]
    var appearance: String?
    var lastSeen: Date
}

@MainActor
final class BLEScanner: NSObject, ObservableObject {
    @Published var peripherals: [ScannedPeripheral] = []
    @Published var isScanning = false
    @Published var stateText = "Idle"
    @Published var filterWatchMouseOnly = true

    private var central: CBCentralManager!
    private var seen: [UUID: ScannedPeripheral] = [:]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func start() {
        guard central.state == .poweredOn else {
            stateText = "Bluetooth not powered on (\(central.state.rawValue))"
            return
        }
        seen.removeAll()
        peripherals.removeAll()
        isScanning = true
        stateText = "Scanning…"
        // Scan broadly — HID may hide service UUID in ADV until connected.
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: true,
        ])
    }

    func stop() {
        central.stopScan()
        isScanning = false
        stateText = "Stopped"
    }

    private func ingest(peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "(no name)"
        if filterWatchMouseOnly {
            let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
            let hasHID = services.contains { $0.uuidString.uppercased().contains("1812") }
            let nameMatch = name.localizedCaseInsensitiveContains("Watch Mouse")
                || name.localizedCaseInsensitiveContains("WatchHID")
            if !nameMatch && !hasHID { return }
        }

        let services = ((advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? [])
            .map(\.uuidString)
        let appearanceNum = advertisementData["kCBAdvDataAppearance"] as? NSNumber
        let appearance = appearanceNum.map { String(format: "0x%04X", $0.intValue) }

        var item = ScannedPeripheral(
            id: peripheral.identifier,
            name: name,
            rssi: rssi.intValue,
            serviceUUIDs: services,
            appearance: appearance,
            lastSeen: Date()
        )
        seen[peripheral.identifier] = item
        peripherals = seen.values.sorted { $0.rssi > $1.rssi }
        if name.localizedCaseInsensitiveContains("Watch Mouse") {
            stateText = "FOUND Watch Mouse (RSSI \(rssi.intValue))"
        }
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            self.stateText = "Central state=\(central.state.rawValue)"
            if central.state == .poweredOn && self.isScanning {
                self.start()
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            self.ingest(peripheral: peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
    }
}
