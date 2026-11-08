import Foundation
import SwiftUI
import WatchConnectivity
import Combine

@MainActor
final class WatchLogInbox: NSObject, ObservableObject {
    @Published var logText: String = "(尚未收到手表日志)"
    @Published var status: String = "WCSession idle"

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
