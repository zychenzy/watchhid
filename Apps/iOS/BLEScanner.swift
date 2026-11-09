import Foundation
import CoreBluetooth
import Combine
import GameController

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

    private var boundedAudit: BoundedHIDClientAudit?
    private var mouseObservers: [NSObjectProtocol] = []
    private var central: CBCentralManager!
    private var diagnosticTarget: CBPeripheral?
    private var diagnosticReads: [CBCharacteristic] = []
    private var diagnosticReading: CBCharacteristic?
    private var diagnosticFingerprints = Set<String>()
    private var seen: [UUID: ScannedPeripheral] = [:]

    override init() {
        super.init()
        if ProcessInfo.processInfo.arguments.contains("--gatt-audit") {
            boundedAudit = BoundedHIDClientAudit()
            boundedAudit?.start()
            return
        }
        central = CBCentralManager(delegate: self, queue: nil)
        logSystemMice()
        for name in [Notification.Name.GCMouseDidConnect, Notification.Name.GCMouseDidDisconnect] {
            mouseObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.logSystemMice() }
            })
        }
    }

    func start() {
        guard central.state == .poweredOn else {
            stateText = "Bluetooth not powered on (\(central.state.rawValue))"
            return
        }
        diagnosticLog("SCAN START")
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

    private func logSystemMice() {
        let mice = GCMouse.mice()
        diagnosticLog("SYSTEM MICE count=\(mice.count) names=\(mice.map { $0.vendorName ?? $0.productCategory })")
    }

    private func diagnosticLog(_ message: String) {
        guard ProcessInfo.processInfo.arguments.contains("--scan") else { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("watchhid-scan.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data((ISO8601DateFormatter().string(from: Date()) + " " + message + "\n").utf8))
    }

    private func ingest(peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name
            ?? "(no name)"
        let diagnosticServices = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []
        let target = name.localizedCaseInsensitiveContains("Watch Mouse")
            || diagnosticServices.contains { $0.uuidString.uppercased() == "A7B10001-7E42-4C63-9D17-B5A0F055C901" }
        if target {
            if ProcessInfo.processInfo.arguments.contains("--connect-target"), diagnosticTarget == nil {
                diagnosticTarget = peripheral
                peripheral.delegate = self
                diagnosticLog("CONNECT TARGET id=\(peripheral.identifier)")
                central.connect(peripheral)
            }
            let fingerprint = "\(peripheral.identifier) \(name) \(diagnosticServices)"
            if diagnosticFingerprints.insert(fingerprint).inserted {
                diagnosticLog("TARGET \(fingerprint) rssi=\(rssi) advertisement=\(advertisementData)")
            }
        }
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
            self.diagnosticLog(self.stateText)
            if central.state == .poweredOn, self.diagnosticTarget == nil,
               let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--target-id=") }),
               let identifier = UUID(uuidString: String(argument.dropFirst("--target-id=".count))) {
                let known = central.retrievePeripherals(withIdentifiers: [identifier])
                self.diagnosticLog("RETRIEVE known target id=\(identifier) count=\(known.count); not advertisement proof")
                if let peripheral = known.first {
                    self.diagnosticTarget = peripheral
                    peripheral.delegate = self
                    central.connect(peripheral)
                }
            }
            if central.state == .poweredOn && (self.isScanning || ProcessInfo.processInfo.arguments.contains("--scan")) {
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


extension BLEScanner: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        Task { @MainActor in
            self.diagnosticLog("SERVICES CHANGED \(invalidatedServices.map { $0.uuid.uuidString })")
            self.diagnosticReads.removeAll()
            self.diagnosticReading = nil
            peripheral.discoverServices(nil)
        }
    }
    private func readNextDiagnostic(_ peripheral: CBPeripheral) {
        guard diagnosticReading == nil, !diagnosticReads.isEmpty else { return }
        let characteristic = diagnosticReads.removeFirst()
        diagnosticReading = characteristic
        peripheral.readValue(for: characteristic)
    }
    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            self.diagnosticLog("GATT VALUE uuid=\(characteristic.uuid) data=\(characteristic.value?.map { String(format: "%02X", $0) }.joined() ?? "nil") error=\(String(describing: error))")
            if self.diagnosticReading === characteristic {
                self.diagnosticReading = nil
                self.readNextDiagnostic(peripheral)
            }
            self.logSystemMice()
        }
    }
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            self.diagnosticLog("GATT SERVICES error=\(String(describing: error))")
            for service in peripheral.services ?? [] {
                self.diagnosticLog("SERVICE uuid=\(service.uuid.uuidString) bytes=\(service.uuid.data.count) data=\(service.uuid.data.map { String(format: "%02X", $0) }.joined())")
                peripheral.discoverCharacteristics(nil, for: service)
            }
            self.logSystemMice()
        }
    }
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            self.diagnosticLog("CHARS service=\(service.uuid) values=\(service.characteristics?.map { $0.uuid.uuidString } ?? []) error=\(String(describing: error))")
            if service.uuid == CBUUID(string: "1812") {
                self.diagnosticReads = (service.characteristics ?? []).filter { $0.properties.contains(.read) }
                self.readNextDiagnostic(peripheral)
            }
        }
    }
}

extension BLEScanner {
    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.diagnosticLog("CONNECTED TARGET id=\(peripheral.identifier)")
            peripheral.discoverServices(nil)
            self.logSystemMice()
        }
    }
    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in self.diagnosticLog("CONNECT FAILED \(String(describing: error))") }
    }
}

/// Read-only, known-peer audit. No scanning, notification subscription, or attribute writes.
@MainActor
final class BoundedHIDClientAudit: NSObject, @preconcurrency CBCentralManagerDelegate, @preconcurrency CBPeripheralDelegate {
    private enum Operation {
        case characteristics(CBService)
        case value(CBCharacteristic)
        case descriptors(CBCharacteristic)
        case descriptorValue(CBDescriptor)
    }
    private var central: CBCentralManager!
    private var peer: CBPeripheral?
    private var stage = 0
    private var operations: [Operation] = []
    private var done = false
    private var operationTimer: Timer?
    private var deadline: Timer?
    private let started = ProcessInfo.processInfo.systemUptime
    private let maxBytes = 131_072
    private var writtenBytes = 0
    private var file: FileHandle?
    private let hid = CBUUID(string: "1812")
    private let dis = CBUUID(string: "180A")

    func start() {
        let name = "watchhid-gatt-audit-\(UUID().uuidString).log"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        file = try? FileHandle(forWritingTo: url)
        log("BEGIN file=\(name) deadline=45s bytes=\(maxBytes) readOnly=true; CB objects/cache are not ATT handles or wire evidence")
        deadline = Timer.scheduledTimer(withTimeInterval: 45, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish("overall deadline") }
        }
        central = CBCentralManager(delegate: self, queue: .main)
    }

    private func log(_ text: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) elapsed=\(String(format: "%.3f", ProcessInfo.processInfo.systemUptime - started)) \(text)\n"
        let bytes = Data(line.utf8)
        guard writtenBytes + bytes.count <= maxBytes else { finish("log cap"); return }
        writtenBytes += bytes.count
        try? file?.write(contentsOf: bytes)
        print(line, terminator: "")
    }
    private func uuid(_ value: CBUUID) -> String {
        "\(value.uuidString) bytes=\(value.data.count) hex=\(value.data.map { String(format: "%02X", $0) }.joined())"
    }
    private func service(_ value: CBService) -> String {
        "service={\(uuid(value.uuid)) object=\(ObjectIdentifier(value)) primary=\(value.isPrimary)}"
    }
    private func characteristic(_ value: CBCharacteristic) -> String {
        "\(value.service.map(service) ?? "service=nil") char={\(uuid(value.uuid)) object=\(ObjectIdentifier(value)) properties=0x\(String(value.properties.rawValue, radix: 16)) notifying=\(value.isNotifying)}"
    }
    private func armOperationTimeout() {
        operationTimer?.invalidate()
        operationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finish("operation timeout; no retry") }
        }
    }
    private func finish(_ reason: String) {
        guard !done else { return }
        done = true
        operationTimer?.invalidate(); deadline?.invalidate()
        operations.removeAll()
        log("END reason=\(reason); cancelling only this client's connection interest; no physical-link claim")
        if let peer, central != nil { central.cancelPeripheralConnection(peer) }
        try? file?.close(); file = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard !done else { return }
        log("CENTRAL state=\(central.state.rawValue)")
        guard central.state == .poweredOn else {
            if central.state == .unauthorized || central.state == .unsupported || central.state == .poweredOff {
                finish("Bluetooth unavailable/permission; no retry")
            }
            return
        }
        guard peer == nil else { return }
        guard let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--target-id=") }),
              let identifier = UUID(uuidString: String(argument.dropFirst("--target-id=".count))),
              let target = central.retrievePeripherals(withIdentifiers: [identifier]).first else {
            finish("known target missing; no scan fallback"); return
        }
        peer = target; target.delegate = self
        log("CONNECT known peer=\(identifier); central identifier is device identity, not app/system process identity")
        armOperationTimeout(); central.connect(target)
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard !done else { return }
        operationTimer?.invalidate()
        log("CONNECTED peer=\(peripheral.identifier)")
        discoverStage(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("CONNECT ERROR \(String(describing: error))"); finish("connect failed")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard !done else { return }
        log("DISCONNECT \(String(describing: error))"); finish("disconnected")
    }
    private func discoverStage(_ peripheral: CBPeripheral) {
        let filter: [CBUUID]? = stage == 0 ? [CBUUID(string: "1812")] : stage == 1 ? [CBUUID(string: "00001812-0000-1000-8000-00805F9B34FB")] : nil
        log("DISCOVER stage=\(stage) filter=\(filter?.map(uuid) ?? ["ALL"]) previouslyCached=\(peripheral.services?.map(service) ?? [])")
        armOperationTimeout(); peripheral.discoverServices(filter)
    }
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard !done else { return }
        log("INVALIDATED \(invalidatedServices.map(service))")
        finish("service change during audit; no automatic restart")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard !done else { return }
        operationTimer?.invalidate()
        let services = peripheral.services ?? []
        log("DISCOVER RESULT stage=\(stage) error=\(String(describing: error)) cacheView=\(services.map(service))")
        guard error == nil else { finish("service discovery error"); return }
        if stage < 2 { stage += 1; discoverStage(peripheral); return }
        let selected = services.filter { $0.uuid == hid || $0.uuid == dis }
        log("DATABASE HID=\(selected.filter { $0.uuid == hid }.count) DIS=\(selected.filter { $0.uuid == dis }.count); distinct objects, UUID semantic equality allowed")
        operations = selected.map(Operation.characteristics)
        next(peripheral)
    }
    private func next(_ peripheral: CBPeripheral) {
        operationTimer?.invalidate()
        guard !done else { return }
        guard !operations.isEmpty else { finish("completed read-only inventory"); return }
        let operation = operations.removeFirst()
        armOperationTimeout()
        switch operation {
        case .characteristics(let item):
            log("READ PLAN characteristics \(service(item))")
            peripheral.discoverCharacteristics(nil, for: item)
        case .value(let item):
            log("READ PLAN value \(characteristic(item))")
            peripheral.readValue(for: item)
        case .descriptors(let item):
            log("READ PLAN descriptors \(characteristic(item))")
            peripheral.discoverDescriptors(for: item)
        case .descriptorValue(let item):
            log("READ PLAN descriptor uuid=\(uuid(item.uuid)) object=\(ObjectIdentifier(item)) \(item.characteristic.map(characteristic) ?? "characteristic=nil")")
            peripheral.readValue(for: item)
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard !done else { return }
        log("CHARACTERISTICS \(self.service(service)) error=\(String(describing: error))")
        var added: [Operation] = []
        for item in service.characteristics ?? [] {
            log("CHARACTERISTIC \(characteristic(item))")
            if item.properties.contains(.read) { added.append(.value(item)) }
            if service.uuid == hid { added.append(.descriptors(item)) }
        }
        if service.uuid == dis {
            log("DIS PNP PRESENT=\(service.characteristics?.contains { $0.uuid == CBUUID(string: "2A50") } ?? false) \(self.service(service))")
        }
        operations.insert(contentsOf: added, at: 0); next(peripheral)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard !done else { return }
        log("VALUE \(self.characteristic(characteristic)) data=\(characteristic.value?.map { String(format: "%02X", $0) }.joined() ?? "nil") error=\(String(describing: error))")
        next(peripheral)
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        guard !done else { return }
        let descriptors = characteristic.descriptors ?? []
        log("DESCRIPTORS \(self.characteristic(characteristic)) values=\(descriptors.map { uuid($0.uuid) }) error=\(String(describing: error))")
        let selected = descriptors.filter { $0.uuid == CBUUID(string: "2908") || $0.uuid == CBUUID(string: "2902") }
        operations.insert(contentsOf: selected.map(Operation.descriptorValue), at: 0); next(peripheral)
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor descriptor: CBDescriptor, error: Error?) {
        guard !done else { return }
        let value = (descriptor.value as? Data)?.map { String(format: "%02X", $0) }.joined() ?? String(describing: descriptor.value)
        log("DESCRIPTOR VALUE uuid=\(uuid(descriptor.uuid)) object=\(ObjectIdentifier(descriptor)) \(descriptor.characteristic.map(characteristic) ?? "characteristic=nil") value=\(value) error=\(String(describing: error))")
        next(peripheral)
    }
}
