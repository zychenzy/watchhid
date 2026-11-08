import Foundation

struct LogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let level: String
    let message: String

    init(level: String, message: String, id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }

    var line: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return "[\(formatter.string(from: timestamp))] [\(level)] \(message)"
    }
}
