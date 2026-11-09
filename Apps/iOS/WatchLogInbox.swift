import Foundation
import SwiftUI
import WatchConnectivity
import Combine

@MainActor
final class WatchLogInbox: NSObject, ObservableObject {
    @Published var logText: String = "(尚未收到手表日志)"
    @Published var status: String = "WCSession idle"

    private var commandSent = false

    private func commandLog(_ text: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("watchhid-command.log")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        guard let file = try? FileHandle(forWritingTo: url) else { return }
        defer { try? file.close() }
        _ = try? file.seekToEnd()
        try? file.write(contentsOf: Data((ISO8601DateFormatter().string(from: Date()) + " " + text + "\n").utf8))
    }

    private func sendPendingCommand() {
        let baselineOnly = ProcessInfo.processInfo.arguments.contains("--r4-baseline")
        guard (baselineOnly || ProcessInfo.processInfo.arguments.contains("--r4-matrix")), !commandSent else { return }
        commandSent = true
        let token = ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--r4-token=") }?.components(separatedBy: "=").last ?? UUID().uuidString
        let payload: [String: Any] = ["type": baselineOnly ? "r4-baseline" : "r4-matrix", "token": token]
        let session = WCSession.default
        commandLog("COMMAND token=\(token) paired=\(session.isPaired) installed=\(session.isWatchAppInstalled) reachable=\(session.isReachable)")
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { reply in
                Task { @MainActor in self.commandLog("COMMAND receipt \(reply)") }
            }, errorHandler: { error in
                Task { @MainActor in
                    self.commandLog("COMMAND immediate error=\(error); queueing normal userInfo")
                    session.transferUserInfo(payload)
                }
            })
        } else {
            session.transferUserInfo(payload)
            commandLog("COMMAND queued userInfo; delivery not yet confirmed")
        }
    }

    func activate() {
        guard WCSession.isSupported() else {
            status = "WCSession unsupported on this device"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }
}

extension WatchLogInbox: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error {
                self.status = "activate error: \(error.localizedDescription)"
            } else {
                self.status = "activated (\(activationState.rawValue))"
                self.sendPendingCommand()
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handle(userInfo)
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        Task { @MainActor in self.commandLog("COMMAND transfer finished error=\(String(describing: error))") }
    }

    private nonisolated func handle(_ payload: [String: Any]) {
        guard (payload["type"] as? String) == "r1-log",
              let text = payload["text"] as? String else { return }
        Task { @MainActor in
            self.logText = text
            self.status = "received log (\(text.count) chars)"
        }
    }
}

struct WatchLogView: View {
    @EnvironmentObject private var inbox: WatchLogInbox

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text(inbox.status).font(.caption).foregroundStyle(.secondary)
                ScrollView {
                    Text(inbox.logText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding()
            .navigationTitle("手表日志")
        }
    }
}
