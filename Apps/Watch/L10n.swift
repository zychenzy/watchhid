import Foundation

/// User-visible Watch strings follow the Watch system language.
/// Only English, Simplified Chinese, and Traditional Chinese are shipped;
/// any other language falls back to English.
enum L10n {
    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: key, comment: "")
        if args.isEmpty {
            return format
        }
        return String(format: format, locale: .current, arguments: args)
    }
}
