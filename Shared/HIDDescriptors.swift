import Foundation

/// Standard USB HID mouse Report Map: 3 buttons + relative X/Y + wheel.
enum HIDDescriptors {
    static let mouseReportMap: [UInt8] = [
        0x05, 0x01, // Usage Page (Generic Desktop)
        0x09, 0x02, // Usage (Mouse)
        0xA1, 0x01, // Collection (Application)
        0x09, 0x01, //   Usage (Pointer)
        0xA1, 0x00, //   Collection (Physical)
        0x05, 0x09, //     Usage Page (Button)
        0x19, 0x01, //     Usage Minimum (1)
        0x29, 0x03, //     Usage Maximum (3)
        0x15, 0x00, //     Logical Minimum (0)
        0x25, 0x01, //     Logical Maximum (1)
        0x95, 0x03, //     Report Count (3)
        0x75, 0x01, //     Report Size (1)
        0x81, 0x02, //     Input (Data,Var,Abs) — buttons
        0x95, 0x01, //     Report Count (1)
        0x75, 0x05, //     Report Size (5)
        0x81, 0x03, //     Input (Const) — padding
        0x05, 0x01, //     Usage Page (Generic Desktop)
        0x09, 0x30, //     Usage (X)
        0x09, 0x31, //     Usage (Y)
        0x09, 0x38, //     Usage (Wheel)
        0x15, 0x81, //     Logical Minimum (-127)
        0x25, 0x7F, //     Logical Maximum (127)
        0x75, 0x08, //     Report Size (8)
        0x95, 0x03, //     Report Count (3)
        0x81, 0x06, //     Input (Data,Var,Rel)
        0xC0,       //   End Collection
        0xC0,       // End Collection
    ]

    /// HID Information: bcdHID=1.11, country=0, flags=normallyConnectable|remoteWake
    static let hidInformation: [UInt8] = [0x11, 0x01, 0x00, 0x02]

    /// Appearance value for a mouse (Bluetooth Assigned Numbers).
    static let mouseAppearance: NSNumber = 0x03C2

    static let localName = "Watch Mouse"

    enum UUID16 {
        static let hidService = "1812"
        static let batteryService = "180F"
        static let deviceInfoService = "180A"
        static let protocolMode = "2A4E"
        static let reportMap = "2A4B"
        static let report = "2A4D"
        static let hidInformation = "2A4A"
        static let hidControlPoint = "2A4C"
        static let batteryLevel = "2A19"
        static let manufacturerName = "2A29"
        static let modelNumber = "2A24"
        static let pnpID = "2A50"
        static let reportReference = "2908"
        static let cccd = "2902"
    }
}
