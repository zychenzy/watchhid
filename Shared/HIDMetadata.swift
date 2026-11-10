import Foundation

/// Immutable read-only values are cached by CoreBluetooth, independent of UI callbacks.
enum HIDMetadata {
    static func value(for uuid: String, keyboardEnabled: Bool = false,
                      pnpID: Data = Data([1, 0x4C, 0, 0, 0, 1, 0])) -> Data? {
        switch uuid.uppercased() {
        case "2A4B": return Data(keyboardEnabled ? HIDDescriptors.mouseKeyboardReportMap : HIDDescriptors.mouseReportMap)
        case "2A4A": return Data(HIDDescriptors.hidInformation)
        case "2A29": return Data("WatchHID".utf8)
        case "2A24": return Data("Ultra2-R1".utf8)
        case "2A50": return pnpID
        default: return nil // Reports, protocol mode and battery remain dynamic.
        }
    }
}
