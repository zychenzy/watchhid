import Foundation
import CoreBluetooth
import WatchKit
import Combine

@MainActor
final class PeripheralProbe: NSObject, ObservableObject {
    static let shared = PeripheralProbe()
    @Published var statusSummary: String = "Idle"
    @Published var isRunning = false
    @Published var reportSubscriberCount = 0
    private var subscribedCentrals = Set<UUID>()
    private var activeReport: NSObject?
    @Published private(set) var mouseEnabled = false
    @Published private(set) var mouseTouching = false
    @Published private(set) var inputStatus = "等待 Mac 订阅"
    private var mouse = MouseInputState()
    private var sceneActive = false
    private var inputTimer: Timer?
    private var clickTask: Task<Void, Never>?
    private var pendingButtonRelease = false
    private let macCentral = UUID(uuidString: "F7A703F6-C354-8E7E-87CB-DEC064EA3CD9")!

    private var macInputReady: Bool {
        isRunning && dynamicPeripheral.map { WHPeripheralState($0) == 5 } == true
            && activeReport != nil && subscribedCentrals == Set([macCentral])
    }

    func prepareMacTouchpad() {
        guard !isRunning else { return }
        experimentOverride = "standard128-dynamic"
        start()
    }

    func setInputSceneActive(_ active: Bool) {
        sceneActive = active
        refreshInputGate()
    }

    private func refreshInputGate() {
        if let release = mouse.availability(active: sceneActive, macReady: macInputReady) {
            finishMouseRelease(release) // completion of a preceding explicit click only
        }
        if !mouse.enabled {
            inputTimer?.invalidate(); inputTimer = nil
            clickTask?.cancel(); clickTask = nil
        }
        mouseEnabled = mouse.enabled
        mouseTouching = mouse.touching
        inputStatus = pendingButtonRelease ? "松键待发送 · 暂停输入" : !sceneActive ? "已暂停 · 返回后重新启用" :
            !macInputReady ? "等待 Mac 系统订阅" : mouse.enabled ? "已启用 · 拖动移动" : "Mac 已订阅 · 待启用"
    }

    func toggleMouseInput() {
        if mouse.enabled {
            if let release = mouse.disarm() { finishMouseRelease(release) }
        } else if !pendingButtonRelease {
            _ = mouse.arm()
        }
        refreshInputGate()
    }

    func touchpadChanged(x: Double, y: Double) {
        guard mouse.enabled && macInputReady && sceneActive else { return }
        if !mouse.touching {
            mouse.beginTouch(x: x, y: y)
            let timer = Timer(timeInterval: MouseInputState.interval, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.drainTouchpad() }
            }
            inputTimer?.invalidate(); inputTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        } else {
            mouse.moveTouch(x: x, y: y)
        }
        mouseTouching = mouse.touching
    }

    func touchpadEnded() {
        mouse.endTouch()
        mouseTouching = false
        inputTimer?.invalidate(); inputTimer = nil
    }

    private func drainTouchpad() {
        guard sceneActive && macInputReady && mouse.enabled else { refreshInputGate(); return }
        if let report = mouse.frame(at: ProcessInfo.processInfo.systemUptime), !submitMouseReport(report) {
            _ = mouse.disarm()
            refreshInputGate()
            inputStatus = "发送忙 · 请重新启用"
        }
    }

    func explicitLeftClick() {
        guard sceneActive && macInputReady && !pendingButtonRelease, let down = mouse.pressClick() else { return }
        guard submitMouseReport(down) else {
            _ = mouse.disarm(); refreshInputGate(); return
        }
        clickTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(80)) } catch { return }
            guard let self else { return }
            if let up = self.mouse.releaseClick() {
                self.finishMouseRelease(up)
                if self.pendingButtonRelease { _ = self.mouse.disarm(); self.refreshInputGate() }
            }
            self.clickTask = nil
        }
    }

    private func finishMouseRelease(_ report: Data) {
        // Only called to finish a successfully submitted, user-requested click.
        pendingButtonRelease = !submitMouseReport(report)
    }

    private func retryPendingRelease() {
        guard pendingButtonRelease else { return }
        if submitMouseReport(Data([0, 0, 0, 0])) {
            pendingButtonRelease = false
            refreshInputGate()
        }
    }

    private func submitMouseReport(_ data: Data) -> Bool {
        guard let peripheral = dynamicPeripheral, let report = activeReport,
              subscribedCentrals == Set([macCentral]) else { return false }
        return WHUpdateReport(peripheral, data, report)
    }

    private var customServiceUUID: String {
        experiment.hasPrefix("custom-fresh") ? "A7B10001-7E42-4C63-9D17-B5A0F055C903" : experiment == "custom-hidshape-v2" ? "A7B10001-7E42-4C63-9D17-B5A0F055C902" : "A7B10001-7E42-4C63-9D17-B5A0F055C901"
    }
    private var experimentOverride: String?
    private var matrixInProgress = false
    private var experiment: String {
        experimentOverride ?? ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--r1-case=") })?
            .components(separatedBy: "=").last ?? "standard128-shortadv"
    }

    private var dynamicValues: Bool {
        experiment == "standard128-dynamic"
            || experiment == "standard128-dynamic-pnpgen"
            || experiment == "standard128-encrypted"
            || experiment == "standard128-hogp-v1"
    }
    private var secureHID: Bool { experiment == "standard128-encrypted" || experiment == "standard128-hogp-v1" }
    /// Narrow HOGP/iOS layout contrast vs darwin-bt-remote LowEnergy (not Continuity root-cause claim).
    private var hogpV1: Bool { experiment == "standard128-hogp-v1" }
    /// Speculative contrast: Apple VID 0x004C may encourage SameAccount merge; generic VID is Mac-only test.
    private var nonApplePnP: Bool { experiment == "standard128-dynamic-pnpgen" }
    private func hogpUUID(short: String, full: String) -> String { hogpV1 ? full : short }
    private var pnpIDBytes: Data {
        nonApplePnP ? Data([0x01, 0xFF, 0xFF, 0x01, 0x00, 0x01, 0x00]) : Data([0x01, 0x4C, 0x00, 0x00, 0x00, 0x01, 0x00])
    }
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

    private var advertisingConfirmed = false
    private var restorationWaiter: CheckedContinuation<Bool, Never>?

    func runDiagnosticMatrix() async {
        guard !matrixInProgress else { return }
        matrixInProgress = true
        defer { matrixInProgress = false }
        var completed = true
        for name in ["standard128-shortadv", "standard128-dynamic", "standard128-encrypted"] {
            stop()
            experimentOverride = name
            log.step("MATRIX CASE \(name) — same process, no UI activation")
            start()
            do { try await Task.sleep(for: .seconds(3)) }
            catch { completed = false; log.warn("Matrix interrupted: \(error)"); break }
        }
        let restored = await restoreDiagnosticBaseline()
        if completed && restored {
            log.info("MATRIX complete — no movement/click sent")
        } else {
            log.warn("MATRIX aborted — baseline advertising not confirmed")
        }
    }

    func restoreDiagnosticBaseline() async -> Bool {
        stop()
        experimentOverride = "standard128-shortadv"
        log.step("MATRIX restoring baseline")
        return await withCheckedContinuation { continuation in
            restorationWaiter = continuation
            start()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if let waiter = self.restorationWaiter {
                    self.restorationWaiter = nil
                    waiter.resume(returning: false)
                }
            }
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        advertisingConfirmed = false
        subscribedCentrals.removeAll()
        reportSubscriberCount = 0
        activeReport = nil
        statusSummary = "Starting…"
        addedServiceCount = 0
        expectedServiceCount = 0
        log.clear()
        log.step("R1 start — WatchHID peripheral probe case=\(experiment)")
        log.info("R2 enumeration is optional and separate from R1")
        createViaDynamicFactory()
    }

    func stop() {
        if let release = mouse.disarm() { finishMouseRelease(release) }
        inputTimer?.invalidate(); inputTimer = nil
        clickTask?.cancel(); clickTask = nil
        if let dyn = dynamicPeripheral {
            WHStopAdvertising(dyn)
            WHRemoveAllServices(dyn)
        }
        dynamicPeripheral = nil
        pendingServiceObjects = []
        isRunning = false
        subscribedCentrals.removeAll()
        reportSubscriberCount = 0
        activeReport = nil
        statusSummary = "Stopped"
        refreshInputGate()
        log.step("Probe stopped")
    }

    func sendMouseTest(click: Bool) {
        guard let peripheral = dynamicPeripheral, let report = activeReport else {
            log.warn("Mouse test requires an actual Report subscriber")
            return
        }
        if !click {
            let accepted = WHUpdateReport(peripheral, Data([0, 20, 0, 0]), report)
            log.info("User-requested relative X=20 report queued=\(accepted)")
        } else {
            Task { @MainActor in
                let down = WHUpdateReport(peripheral, Data([1, 0, 0, 0]), report)
                try? await Task.sleep(nanoseconds: 80_000_000)
                let up = WHUpdateReport(peripheral, Data([0, 0, 0, 0]), report)
                self.log.info("User-requested click reports queued down=\(down) up=\(up)")
            }
        }
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
        if experiment == "name-only" {
            log.info("Control: no GATT service registration")
            startAdvertising()
            return
        }
        if experiment == "r2-uuid-matrix" {
            let uuids = ["1812", "180F", "180A", "180D", customServiceUUID]
            pendingServiceObjects = uuids.compactMap { uuid in
                guard let service = WHCreateMutableService(uuid, true) as? NSObject,
                      let characteristic = WHCreateMutableCharacteristic(
                        "A7B10002-7E42-4C63-9D17-B5A0F055C901", propRead, Data([0x01]), permReadable) else { return nil }
                WHSetCharacteristics(service, [characteristic])
                return service
            }
            expectedServiceCount = pendingServiceObjects.count
            addedServiceCount = 0
            for service in pendingServiceObjects {
                let uuid = (service.value(forKey: "UUID") as? CBUUID)?.uuidString ?? "unknown"
                log.info("Minimal identical attribute structure addService \(uuid)")
                if let exception = WHAddServiceChecked(dyn, service) { log.error(exception) }
            }
            return
        }
        if experiment.hasPrefix("custom-hidshape") {
            guard let service = buildHIDService(uuidOverride: customServiceUUID) else {
                log.error("HID-shape construction failed")
                return
            }
            pendingServiceObjects = [service]
            expectedServiceCount = 1
            addedServiceCount = 0
            log.info("HID characteristic shape under non-HID custom service UUID")
            if let exception = WHAddServiceChecked(dyn, service) { log.error(exception) }
            return
        }
        if experiment.hasPrefix("custom") {
            guard let service = WHCreateMutableService(customServiceUUID, true) as? NSObject,
                  let characteristic = WHCreateMutableCharacteristic(
                    experiment.hasPrefix("custom-fresh") ? "A7B10002-7E42-4C63-9D17-B5A0F055C903" : "A7B10002-7E42-4C63-9D17-B5A0F055C901", propRead, experiment == "custom-fresh-dynamic" ? nil : Data([0x01]), permReadable) else {
                log.error("Custom service construction failed")
                return
            }
            WHSetCharacteristics(service, [characteristic])
            pendingServiceObjects = [service]
            expectedServiceCount = 1
            addedServiceCount = 0
            log.info("addService custom \(customServiceUUID)")
            if let exception = WHAddServiceChecked(dyn, service) {
                log.error("custom addService exception: \(exception)")
                startAdvertising()
            }
            return
        }

        let expanded = experiment.hasPrefix("standard128")
        if let short = WHCreateUUID("1812") as? CBUUID,
           let full = WHCreateUUID("00001812-0000-1000-8000-00805F9B34FB") as? CBUUID {
            log.info("Public UUID representation: shortBytes=\(short.data.count) fullBytes=\(full.data.count) equal=\(short == full)")
        }
        guard let hid = buildHIDService(uuidOverride: expanded ? "00001812-0000-1000-8000-00805F9B34FB" : nil),
              let battery = buildBatteryService(uuidOverride: expanded ? "0000180F-0000-1000-8000-00805F9B34FB" : nil),
              let info = buildDeviceInfoService(uuidOverride: expanded ? "0000180A-0000-1000-8000-00805F9B34FB" : nil) else {
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
            if let exception = WHAddServiceChecked(dyn, service) {
                log.error("addService \(uuid) exception: \(exception)")
                statusSummary = "Service rejected: \(uuid)"
            }
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if self.addedServiceCount == 0 {
                self.log.warn("No didAddService callbacks after 1s — advertising anyway")
                self.startAdvertising()
            }
        }
    }

    private func buildHIDService(uuidOverride: String? = nil) -> NSObject? {
        guard let service = WHCreateMutableService(uuidOverride ?? HIDDescriptors.UUID16.hidService, true) as? NSObject else { return nil }

        let protocolMode = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.protocolMode, full: HIDDescriptors.UUID128.protocolMode),
            propRead | propWriteWithoutResponse,
            nil,
            secureHID ? (0x04 | 0x08) : (permReadable | permWriteable) // enc: read+writeEncryptionRequired
        )
        let reportMap = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.reportMap, full: HIDDescriptors.UUID128.reportMap),
            propRead,
            dynamicValues ? nil : Data(HIDDescriptors.mouseReportMap),
            secureHID ? 0x04 : permReadable
        )
        let report = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.report, full: HIDDescriptors.UUID128.report),
            propRead | propNotify | (secureHID ? 0x100 : 0),
            nil,
            secureHID ? 0x04 : permReadable
        ) as? NSObject
        if let report {
            if let reportRef = WHCreateMutableDescriptor(
                hogpUUID(short: HIDDescriptors.UUID16.reportReference, full: HIDDescriptors.UUID128.reportReference),
                Data([0x00, 0x01])
            ) {
                WHSetDescriptors(report, [reportRef])
            }
        }
        let hidInfo = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.hidInformation, full: HIDDescriptors.UUID128.hidInformation),
            propRead,
            dynamicValues ? nil : Data(HIDDescriptors.hidInformation),
            secureHID ? 0x04 : permReadable
        )
        // HOGP: Control Point is Write Without Response (keep spec; do not copy darwin .read-only anomaly).
        let controlPoint = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.hidControlPoint, full: HIDDescriptors.UUID128.hidControlPoint),
            propWriteWithoutResponse,
            nil,
            secureHID ? 0x08 : permWriteable
        )

        var chars: [Any] = []
        if hogpV1 {
            // Order closer to darwin-bt-remote HIDPeripheral.buildHIDService
            chars.append(contentsOf: [controlPoint, protocolMode, hidInfo].compactMap { $0 })
            let bootMouse = WHCreateMutableCharacteristic(
                hogpUUID(short: HIDDescriptors.UUID16.bootMouseInputReport, full: HIDDescriptors.UUID128.bootMouseInputReport),
                propRead | propNotify | 0x100,
                nil,
                0x04
            )
            if let bootMouse { chars.append(bootMouse) }
            chars.append(contentsOf: [reportMap, report].compactMap { $0 })
        } else {
            chars.append(contentsOf: [protocolMode, reportMap, report, hidInfo, controlPoint].compactMap { $0 })
        }
        WHSetCharacteristics(service, chars)
        return service
    }

    private func buildBatteryService(uuidOverride: String? = nil) -> NSObject? {
        guard let service = WHCreateMutableService(uuidOverride ?? HIDDescriptors.UUID16.batteryService, true) as? NSObject else { return nil }
        let batProps: UInt = propRead | propNotify | (hogpV1 ? 0x100 : 0)
        let batPerm: UInt = hogpV1 ? 0x04 : permReadable
        if let level = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.batteryLevel, full: HIDDescriptors.UUID128.batteryLevel),
            batProps,
            nil,
            batPerm
        ) {
            WHSetCharacteristics(service, [level])
        }
        return service
    }

    private func buildDeviceInfoService(uuidOverride: String? = nil) -> NSObject? {
        guard let service = WHCreateMutableService(uuidOverride ?? HIDDescriptors.UUID16.deviceInfoService, true) as? NSObject else { return nil }
        let manufacturer = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.manufacturerName, full: HIDDescriptors.UUID128.manufacturerName),
            propRead,
            dynamicValues ? nil : Data("WatchHID".utf8),
            permReadable
        )
        let model = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.modelNumber, full: HIDDescriptors.UUID128.modelNumber),
            propRead,
            dynamicValues ? nil : Data("Ultra2-R1".utf8),
            permReadable
        )
        let pnp = WHCreateMutableCharacteristic(
            hogpUUID(short: HIDDescriptors.UUID16.pnpID, full: HIDDescriptors.UUID128.pnpID),
            propRead,
            dynamicValues ? nil : pnpIDBytes,
            permReadable
        )
        WHSetCharacteristics(service, [manufacturer, model, pnp].compactMap { $0 })
        return service
    }

    private func startAdvertising() {
        guard let dyn = dynamicPeripheral else { return }
        var advertisement: [String: Any] = [WHAdvertisementLocalNameKey: HIDDescriptors.localName]
        // darwin-bt-remote advertises LocalName + short 1812 only; Appearance is HOGP "should", not required.
        if !hogpV1 && (experiment == "standard" || experiment.hasPrefix("standard128") || experiment == "custom-appearance") {
            advertisement[WHAdvertisementAppearanceKey] = HIDDescriptors.mouseAppearance
        }
        let serviceUUID = experiment.hasPrefix("custom") ? customServiceUUID : (experiment == "standard128" ? "00001812-0000-1000-8000-00805F9B34FB" : HIDDescriptors.UUID16.hidService)
        if experiment != "name-only", let uuid = WHCreateUUID(serviceUUID) {
            advertisement[WHAdvertisementServiceUUIDsKey] = [uuid]
        }
        log.step("startAdvertising case=\(experiment) data=\(advertisement)")
        if let exception = WHStartAdvertisingChecked(dyn, advertisement) {
            log.error("startAdvertising exception: \(exception)")
            statusSummary = "Advertising exception"
            return
        }
        let advertising = WHIsAdvertising(dyn)
        log.info("startAdvertising invoked; isAdvertising=\(advertising)")
        statusSummary = advertising ? "Advertising: Watch Mouse" : "Advertise requested"
    }
}

extension PeripheralProbe: CBPeripheralManagerDelegate {
    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // Respond on the CoreBluetooth callback queue before any MainActor hop.
        // Background WatchConnectivity budgets previously exhausted while ATT replies waited on UI work.
        let uuid = request.characteristic.uuid
        let trace = ATTCallbackTrace.begin(uuid: uuid.uuidString,
            central: request.central.identifier.uuidString,
            manager: String(describing: ObjectIdentifier(peripheral)), offset: request.offset)
        let value: Data?
        if uuid == CBUUID(string: HIDDescriptors.UUID16.protocolMode) {
            value = Data([1])
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.reportMap) {
            value = Data(HIDDescriptors.mouseReportMap)
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.hidInformation) {
            value = Data(HIDDescriptors.hidInformation)
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.manufacturerName) {
            value = Data("WatchHID".utf8)
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.modelNumber) {
            value = Data("Ultra2-R1".utf8)
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.pnpID) {
            let caseName = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--r1-case=") })?.components(separatedBy: "=").last
            value = (caseName == "standard128-dynamic-pnpgen")
                ? Data([0x01, 0xFF, 0xFF, 0x01, 0x00, 0x01, 0x00])
                : Data([0x01, 0x4C, 0x00, 0x00, 0x00, 0x01, 0x00])
        } else if uuid == CBUUID(string: "A7B10002-7E42-4C63-9D17-B5A0F055C903") {
            value = Data([1])
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.report)
                    || uuid == CBUUID(string: HIDDescriptors.UUID128.report) {
            value = Data([0, 0, 0, 0])
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.bootMouseInputReport)
                    || uuid == CBUUID(string: HIDDescriptors.UUID128.bootMouseInputReport) {
            value = Data([0, 0, 0]) // USB HID boot mouse: buttons, X, Y
        } else if uuid == CBUUID(string: HIDDescriptors.UUID16.batteryLevel)
                    || uuid == CBUUID(string: HIDDescriptors.UUID128.batteryLevel) {
            value = Data([100])
        } else {
            value = request.characteristic.value
        }
        let result: Int
        let repliedBytes: Int
        if let value {
            if request.offset <= value.count {
                request.value = value.subdata(in: request.offset..<value.count)
                repliedBytes = request.value?.count ?? 0
                result = CBATTError.Code.success.rawValue
            } else {
                repliedBytes = 0
                result = CBATTError.Code.invalidOffset.rawValue
            }
        } else {
            repliedBytes = 0
            result = CBATTError.Code.requestNotSupported.rawValue
        }
        WHRespondToRequest(peripheral, request, result)
        ATTCallbackTrace.finish(trace, result: result, bytes: repliedBytes)
        let callbackTime = ISO8601DateFormatter().string(from: trace.wall)
        let central = request.central.identifier
        let offset = request.offset
        Task { @MainActor in
            self.log.info("ATT read \(uuid.uuidString) central=\(central) offset=\(offset) bytes=\(repliedBytes) result=\(result) callbackTime=\(callbackTime) appStateAtLog=\(WKApplication.shared().applicationState.rawValue)")
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // HOGP Protocol Mode / Control Point writes; respond before MainActor logging.
        for request in requests {
            let uuid = request.characteristic.uuid
            let payload = request.value ?? Data()
            if uuid == CBUUID(string: HIDDescriptors.UUID16.protocolMode) {
                WHRespondToRequest(peripheral, request, CBATTError.Code.success.rawValue)
                Task { @MainActor in
                    self.log.info("ATT write Protocol Mode bytes=\(payload.map { String(format: "%02X", $0) }.joined()) appState=\(WKApplication.shared().applicationState.rawValue)")
                }
            } else if uuid == CBUUID(string: HIDDescriptors.UUID16.hidControlPoint) {
                WHRespondToRequest(peripheral, request, CBATTError.Code.success.rawValue)
                Task { @MainActor in
                    self.log.info("ATT write HID Control Point bytes=\(payload.map { String(format: "%02X", $0) }.joined()) appState=\(WKApplication.shared().applicationState.rawValue)")
                }
            } else {
                WHRespondToRequest(peripheral, request, CBATTError.Code.requestNotSupported.rawValue)
                Task { @MainActor in
                    self.log.warn("ATT write unsupported \(uuid.uuidString)")
                }
            }
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        Task { @MainActor in
            self.log.info("ATT subscribed \(characteristic.uuid) central=\(central.identifier)")
            if characteristic.uuid == CBUUID(string: HIDDescriptors.UUID16.report) {
                self.subscribedCentrals.insert(central.identifier)
                self.reportSubscriberCount = self.subscribedCentrals.count
                self.activeReport = characteristic
                self.retryPendingRelease()
                self.refreshInputGate()
                self.log.info("Input gate updated; no new input, except completing a pending explicit click release")
            }
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        Task { @MainActor in
            guard characteristic.uuid == CBUUID(string: HIDDescriptors.UUID16.report) else { return }
            self.subscribedCentrals.remove(central.identifier)
            self.reportSubscriberCount = self.subscribedCentrals.count
            if self.subscribedCentrals.isEmpty { self.activeReport = nil }
            self.refreshInputGate()
            self.log.info("ATT unsubscribed \(characteristic.uuid) central=\(central.identifier)")
        }
    }

    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            self.dynamicPeripheral = peripheral
            self.log.info("Delegate didUpdateState → \(self.stateName(peripheral.state.rawValue))")
            self.refreshInputGate()
            self.pollStateAndContinue()
        }
    }

    nonisolated func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        Task { @MainActor in self.retryPendingRelease() }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        Task { @MainActor in
            if let error {
                self.log.error("didAddService \(service.uuid.uuidString) FAILED: \(error.localizedDescription) domain=\((error as NSError).domain) code=\((error as NSError).code)")
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
                self.advertisingConfirmed = peripheral.isAdvertising
                self.log.info("didStartAdvertising OK — isAdvertising=\(peripheral.isAdvertising)")
                self.statusSummary = peripheral.isAdvertising ? "Advertising: Watch Mouse" : "Advertise OK but isAdvertising=false"
            }
            if let waiter = self.restorationWaiter {
                self.restorationWaiter = nil
                waiter.resume(returning: error == nil && peripheral.isAdvertising)
            }
        }
    }
}
