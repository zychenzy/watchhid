import Foundation
import CoreBluetooth
import Combine

@MainActor
final class PeripheralProbe: NSObject, ObservableObject {
    @Published var statusSummary: String = "Idle"
    @Published var isRunning = false

    private var dynamicPeripheral: NSObject?
    private var pendingServiceObjects: [NSObject] = []
    private var addedServiceCount = 0
    private var expectedServiceCount = 0

    private let log = LogStore.shared

    // CBCharacteristicProperties / permissions raw values (mirror CoreBluetooth)
    private let propRead: UInt = 0x02
    private let propWriteWithoutResponse: UInt = 0x04
    private let propNotify: UInt = 0x10
    private let permReadable: UInt = 0x01
    private let permWriteable: UInt = 0x02

    func start() {
        guard !isRunning else { return }
        isRunning = true
        statusSummary = "Starting…"
        addedServiceCount = 0
        expectedServiceCount = 0
        log.clear()
        log.step("R1 start — WatchHID peripheral probe")
        log.step("R2: runtime enumeration first")
        _ = RuntimeEnumerator.runProbe { [weak self] line in
            Task { @MainActor in self?.log.info(line) }
        }
        createViaDynamicFactory()
    }

    func stop() {
        if let dyn = dynamicPeripheral {
            WHStopAdvertising(dyn)
            WHRemoveAllServices(dyn)
        }
        dynamicPeripheral = nil
        pendingServiceObjects = []
        isRunning = false
        statusSummary = "Stopped"
        log.step("Probe stopped")
    }

    private func createViaDynamicFactory() {
        log.step("Create CBPeripheralManager via WHCreatePeripheralManager (dynamic)")
        var error: NSError?
        let queue = DispatchQueue(label: "com.zy.watchhid.peripheral")
        guard let obj = WHCreatePeripheralManager(self, queue, &error) else {
            let msg = error?.localizedDescription ?? "unknown"
            log.error("Dynamic create failed: \(msg)")
            statusSummary = "Create failed: \(msg)"
            isRunning = false
            return
        }
        dynamicPeripheral = obj as? NSObject
        log.info("Dynamic CBPeripheralManager instance: \(obj)")
        pollStateAndContinue()
    }

    private func pollStateAndContinue() {
        guard let dyn = dynamicPeripheral else { return }
        let stateValue = Int(WHPeripheralState(dyn))
        log.info("Peripheral state raw=\(stateValue) (\(stateName(stateValue)))")
        statusSummary = "State: \(stateName(stateValue))"

        switch stateValue {
        case CBManagerState.poweredOn.rawValue:
            addHIDServices()
        case CBManagerState.unsupported.rawValue:
            log.error("State=unsupported — public peripheral role blocked; still probing add/advertise errors")
            statusSummary = "unsupported"
            addHIDServices()
        case CBManagerState.unauthorized.rawValue:
            log.error("State=unauthorized — check Bluetooth permission")
            statusSummary = "unauthorized"
            isRunning = false
        case CBManagerState.poweredOff.rawValue:
            log.warn("State=poweredOff — waiting for poweredOn")
        default:
            log.info("Waiting for state update…")
        }
    }

    private func stateName(_ raw: Int) -> String {
        switch raw {
        case 0: return "unknown"
        case 1: return "resetting"
        case 2: return "unsupported"
        case 3: return "unauthorized"
        case 4: return "poweredOff"
        case 5: return "poweredOn"
        default: return "raw(\(raw))"
        }
    }

    private func addHIDServices() {
        log.step("Building HID / Battery / Device Information via dynamic CBMutable*")
        guard let dyn = dynamicPeripheral else { return }

        guard let hid = buildHIDService(),
              let battery = buildBatteryService(),
              let info = buildDeviceInfoService() else {
            log.error("Failed to construct one or more mutable services (classes missing?)")
            statusSummary = "GATT build failed"
            return
        }

        pendingServiceObjects = [hid, battery, info]
        expectedServiceCount = pendingServiceObjects.count
        addedServiceCount = 0

        WHRemoveAllServices(dyn)
        for service in pendingServiceObjects {
            let uuid = (service.value(forKey: "UUID") as? CBUUID)?.uuidString
                ?? String(describing: service)
            log.info("addService \(uuid)")
            WHAddService(dyn, service)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if self.addedServiceCount == 0 {
                self.log.warn("No didAddService callbacks after 1s — advertising anyway")
                self.startAdvertising()
            }
        }
    }

    private func buildHIDService() -> NSObject? {
        guard let service = WHCreateMutableService(HIDDescriptors.UUID16.hidService, true) as? NSObject else { return nil }

        let protocolMode = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.protocolMode,
            propRead | propWriteWithoutResponse,
            Data([0x01]),
            permReadable | permWriteable
        )
        let reportMap = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.reportMap,
            propRead,
            Data(HIDDescriptors.mouseReportMap),
            permReadable
        )
        let report = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.report,
            propRead | propNotify,
            nil,
            permReadable
        ) as? NSObject
        if let report {
            if let reportRef = WHCreateMutableDescriptor(
                HIDDescriptors.UUID16.reportReference,
                Data([0x00, 0x01])
            ) {
                WHSetDescriptors(report, [reportRef])
            }
        }
        let hidInfo = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.hidInformation,
            propRead,
            Data(HIDDescriptors.hidInformation),
            permReadable
        )
        let controlPoint = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.hidControlPoint,
            propWriteWithoutResponse,
            nil,
            permWriteable
        )

        let chars = [protocolMode, reportMap, report, hidInfo, controlPoint].compactMap { $0 }
        WHSetCharacteristics(service, chars)
        return service
    }

    private func buildBatteryService() -> NSObject? {
        guard let service = WHCreateMutableService(HIDDescriptors.UUID16.batteryService, true) as? NSObject else { return nil }
        if let level = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.batteryLevel,
            propRead | propNotify,
            Data([100]),
            permReadable
        ) {
            WHSetCharacteristics(service, [level])
        }
        return service
    }

    private func buildDeviceInfoService() -> NSObject? {
        guard let service = WHCreateMutableService(HIDDescriptors.UUID16.deviceInfoService, true) as? NSObject else { return nil }
        let manufacturer = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.manufacturerName,
            propRead,
            Data("WatchHID".utf8),
            permReadable
        )
        let model = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.modelNumber,
            propRead,
            Data("Ultra2-R1".utf8),
            permReadable
        )
        let pnp = WHCreateMutableCharacteristic(
            HIDDescriptors.UUID16.pnpID,
            propRead,
            Data([0x01, 0x4C, 0x00, 0x00, 0x00, 0x01, 0x00]),
            permReadable
        )
        WHSetCharacteristics(service, [manufacturer, model, pnp].compactMap { $0 })
        return service
    }

    private func startAdvertising() {
        log.step("startAdvertising name=Watch Mouse appearance=0x03C2 services=1812")
        guard let dyn = dynamicPeripheral else { return }
        var advertisement: [String: Any] = [
            WHAdvertisementLocalNameKey: HIDDescriptors.localName,
            WHAdvertisementAppearanceKey: HIDDescriptors.mouseAppearance,
        ]
        if let uuid = WHCreateUUID(HIDDescriptors.UUID16.hidService) {
            advertisement[WHAdvertisementServiceUUIDsKey] = [uuid]
        }
        WHStartAdvertising(dyn, advertisement)
        let advertising = WHIsAdvertising(dyn)
        log.info("startAdvertising invoked; isAdvertising=\(advertising)")
        statusSummary = advertising ? "Advertising: Watch Mouse" : "Advertise requested"
    }
}

extension PeripheralProbe: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            self.dynamicPeripheral = peripheral
            self.log.info("Delegate didUpdateState → \(self.stateName(peripheral.state.rawValue))")
            self.pollStateAndContinue()
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        Task { @MainActor in
            if let error {
                self.log.error("didAddService \(service.uuid.uuidString) FAILED: \(error.localizedDescription)")
                self.statusSummary = "addService error: \(error.localizedDescription)"
            } else {
                self.log.info("didAddService OK \(service.uuid.uuidString)")
            }
            self.addedServiceCount += 1
            if self.addedServiceCount >= self.expectedServiceCount && self.expectedServiceCount > 0 {
                self.log.step("All \(self.expectedServiceCount) addService callbacks received — advertising")
                self.startAdvertising()
            }
        }
    }

    nonisolated func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        Task { @MainActor in
            if let error {
                self.log.error("didStartAdvertising FAILED: \(error.localizedDescription)")
                self.statusSummary = "Advertise error: \(error.localizedDescription)"
            } else {
                self.log.info("didStartAdvertising OK — isAdvertising=\(peripheral.isAdvertising)")
                self.statusSummary = peripheral.isAdvertising ? "Advertising: Watch Mouse" : "Advertise OK but isAdvertising=false"
            }
        }
    }
}
