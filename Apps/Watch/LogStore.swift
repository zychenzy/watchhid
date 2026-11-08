import Foundation
import os.log
import Combine

@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [LogEntry] = []
    private let logger = Logger(subsystem: "com.zy.watchhid.watchkitapp", category: "R1")

    func info(_ message: String) { append(level: "INFO", message: message) }
    func warn(_ message: String) { append(level: "WARN", message: message) }
    func error(_ message: String) { append(level: "ERROR", message: message) }
    func step(_ message: String) { append(level: "STEP", message: message) }

    func clear() { entries.removeAll() }

    func exportText() -> String {
        entries.map(\.line).joined(separator: "\n")
    }

    private func append(level: String, message: String) {
        let entry = LogEntry(level: level, message: message)
        entries.append(entry)
        switch level {
        case "ERROR": logger.error("\(message, privacy: .public)")
        case "WARN": logger.warning("\(message, privacy: .public)")
        default: logger.log("\(message, privacy: .public)")
        }
    }
}
