import Foundation
import os.log
import Combine

@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    @Published private(set) var entries: [LogEntry] = []
    private let logger = Logger(subsystem: "com.zy.watchhid.watchkitapp", category: "R1")

    private let logURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("watchhid-r1.log")

    private init() {
        append(level: "INFO", message: "App session started; persistent phase log enabled")
    }

    func info(_ message: String) { append(level: "INFO", message: message) }
    func warn(_ message: String) { append(level: "WARN", message: message) }
    func error(_ message: String) { append(level: "ERROR", message: message) }
    func step(_ message: String) { append(level: "STEP", message: message) }

    func clear() { entries.removeAll() }

    func exportText() -> String {
        (try? String(contentsOf: logURL, encoding: .utf8))
            ?? entries.map(\.line).joined(separator: "\n")
    }

    private func append(level: String, message: String) {
        let entry = LogEntry(level: level, message: message)
        entries.append(entry)
        if entries.count > 500 { entries.removeFirst(entries.count - 500) }
        do {
            try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
            }
            let file = try FileHandle(forWritingTo: logURL)
            defer { try? file.close() }
            try file.seekToEnd()
            try file.write(contentsOf: Data((entry.line + "\n").utf8))
        } catch {
            logger.error("Persistent log failed: \(error.localizedDescription, privacy: .public)")
        }
        switch level {
        case "ERROR": logger.error("\(message, privacy: .public)")
        case "WARN": logger.warning("\(message, privacy: .public)")
        default: logger.log("\(message, privacy: .public)")
        }
    }
}

/// Callback evidence independent of MainActor/UI logging. No runtime/lifecycle changes.
/// The entry is emitted to unified logging before responding; the paired file row is
/// appended only after respondToRequest returns, so disk work never delays that reply.
enum ATTCallbackTrace {
    struct Ticket {
        let id: String
        let wall: Date
        let uptime: TimeInterval
        let uuid: String
        let central: String
        let manager: String
        let offset: Int
        let mainThread: Bool
    }
    private static let logger = Logger(subsystem: "com.zy.watchhid.watchkitapp", category: "ATTCallback")
    private static let fileLock = NSLock()
    /// Opt-in only. Default builds do not write GATT identifiers to unified logs or the JSONL file.
    private static var verbose: Bool {
        ProcessInfo.processInfo.arguments.contains("--watchhid-verbose-att")
            || ProcessInfo.processInfo.environment["WATCHHID_VERBOSE_ATT"] == "1"
    }

    static func begin(uuid: String, central: String, manager: String, offset: Int) -> Ticket {
        let ticket = Ticket(id: UUID().uuidString, wall: Date(), uptime: ProcessInfo.processInfo.systemUptime,
                            uuid: uuid, central: central, manager: manager, offset: offset,
                            mainThread: Thread.isMainThread)
        if verbose {
            logger.notice("ATT_ENTER id=\(ticket.id, privacy: .public) uuid=\(uuid, privacy: .private) central=\(central, privacy: .private) main=\(ticket.mainThread)")
        }
        return ticket
    }

    static func finish(_ ticket: Ticket, result: Int, bytes: Int) {
        let end = ProcessInfo.processInfo.systemUptime
        guard verbose else { return }
        logger.notice("ATT_RESPOND_RETURN id=\(ticket.id, privacy: .public) result=\(result) bytes=\(bytes)")
        let row: [String: Any] = [
            "event": "att_response_return", "id": ticket.id,
            "callback_time": ISO8601DateFormatter().string(from: ticket.wall),
            "callback_epoch": ticket.wall.timeIntervalSince1970,
            "callback_uptime": ticket.uptime, "response_uptime": end,
            "latency_ms": (end - ticket.uptime) * 1000,
            "uuid": ticket.uuid, "central": ticket.central, "manager": ticket.manager,
            "offset": ticket.offset, "bytes": bytes, "result": result,
            "pid": ProcessInfo.processInfo.processIdentifier, "main_thread": ticket.mainThread
        ]
        fileLock.lock()
        defer { fileLock.unlock() }
        do {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("watchhid-att-callback.jsonl")
            if !FileManager.default.fileExists(atPath: url.path) {
                guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            // Bounded diagnostic artifact, no automatic deletion/rotation.
            guard try handle.seekToEnd() < 131_072 else {
                logger.error("ATT_TRACE_CAP reached; missing file rows must not be interpreted as no callback")
                return
            }
            var data = try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])
            data.append(0x0A)
            try handle.write(contentsOf: data)
        } catch {
            logger.error("ATT_TRACE_FILE_ERROR \(error.localizedDescription, privacy: .public)")
        }
    }
}
