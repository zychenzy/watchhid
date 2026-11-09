import Foundation
import ObjectiveC
import Darwin

enum RuntimeEnumerator {
    static func runProbe(log: (String) -> Void) -> String {
        var lines: [String] = []
        func out(_ s: String) {
            lines.append(s)
            log(s)
        }

        out("=== R2 Runtime Enumeration ===")

        if let cls = NSClassFromString("CBPeripheralManager") {
            out("CBPeripheralManager class: \(NSStringFromClass(cls))")
            dumpMethods(of: cls, label: "CBPeripheralManager", out: out)
        } else {
            out("CBPeripheralManager: NOT FOUND via NSClassFromString")
        }

        let interesting = ["Peripheral", "Advertis", "GATT", "HID", "Bluetooth", "BTLE", "CBStack"]
        var matched: [String] = []
        for name in WHRuntimeClassNames() {
            if interesting.contains(where: { name.localizedCaseInsensitiveContains($0) }) {
                matched.append(name)
            }
        }
        matched.sort()
        out("Matched classes (\(matched.count)):")
        for name in matched.prefix(200) {
            out("  - \(name)")
        }
        if matched.count > 200 {
            out("  … \(matched.count - 200) more omitted")
        }

        for framework in [
            "CoreBluetooth",
            "BluetoothManager",
            "MobileBluetooth",
            "GATT",
        ] {
            probeFramework(framework, out: out)
        }

        if let pm = NSClassFromString("CBPeripheralManager") {
            for selName in [
                "initWithDelegate:queue:",
                "initWithDelegate:queue:options:",
                "startAdvertising:",
                "stopAdvertising",
                "addService:",
                "removeAllServices",
                "isAdvertising",
                "state",
            ] {
                let sel = NSSelectorFromString(selName)
                let instancesRespond = (pm as AnyObject).responds(to: sel) // class object may not
                let classResponds = pm.instancesRespond(to: sel)
                out("selector \(selName): instancesRespond=\(classResponds) metaProbe=\(instancesRespond)")
            }
        }

        for name in matched where name.hasPrefix("CBStack") || name.hasPrefix("BTLE") || name.hasPrefix("Bluetooth") {
            out("FOCUSED class \(name)")
        }
        for line in WHRuntimeClassDetails(["CBStack", "BluetoothDevice", "CBStackPeripheral", "CBHIDService", "HIDUserDevice", "BluetoothManager", "BTDevice", "CBMutableService", "CBManager"]) {
            out(line)
        }
        out("=== End R2 Enumeration ===")
        return lines.joined(separator: "\n")
    }

    private static func dumpMethods(of cls: AnyClass, label: String, out: (String) -> Void) {
        var methodCount: UInt32 = 0
        guard let methods = class_copyMethodList(cls, &methodCount) else {
            out("\(label) methods: none")
            return
        }
        defer { free(methods) }
        out("\(label) instance methods (\(methodCount)):")
        for i in 0..<Int(methodCount) {
            let sel = method_getName(methods[i])
            out("  • \(NSStringFromSelector(sel))")
        }

        if let meta = object_getClass(cls) {
            var metaCount: UInt32 = 0
            if let metaMethods = class_copyMethodList(meta, &metaCount) {
                defer { free(metaMethods) }
                out("\(label) class methods (\(metaCount)):")
                for i in 0..<Int(metaCount) {
                    let sel = method_getName(metaMethods[i])
                    out("  ◦ \(NSStringFromSelector(sel))")
                }
            }
        }
    }

    private static func probeFramework(_ name: String, out: (String) -> Void) {
        let paths = [
            "/System/Library/Frameworks/\(name).framework/\(name)",
            "/System/Library/PrivateFrameworks/\(name).framework/\(name)",
        ]
        for path in paths {
            let handle = dlopen(path, RTLD_LAZY)
            if handle != nil {
                out("dlopen OK: \(path)")
                dlclose(handle)
                return
            }
        }
        out("dlopen miss: \(name)")
    }
}
