import SwiftUI
import WatchConnectivity
import WatchKit

@main
struct WatchHIDWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchBackgroundDelegate.self) private var backgroundDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var probe = PeripheralProbe.shared
    @StateObject private var logStore = LogStore.shared
    @StateObject private var phoneBridge = PhoneBridge.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(probe)
                .environmentObject(logStore)
                .environmentObject(phoneBridge)
                .onAppear { phoneBridge.activate(); logStore.info("Scene appeared phase=\(String(describing: scenePhase))") }
                .onChange(of: scenePhase) { _, phase in logStore.info("Scene phase=\(String(describing: phase))") }
        }
    }
}

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var probe: PeripheralProbe
    @EnvironmentObject private var logStore: LogStore
    @EnvironmentObject private var phoneBridge: PhoneBridge
    @State private var showSettings = false
    @State private var dictationPresented = false
    #if targetEnvironment(simulator)
    @State private var simulatorCheckRan = false
    #endif
    private var inputOverlayVisible: Bool { showSettings || dictationPresented }

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(probe.mouseEnabled ? Color.blue.opacity(0.28) : Color.gray.opacity(0.15))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        probe.touchpadChanged(x: Double(value.location.x), y: Double(value.location.y))
                    }
                    .onEnded { _ in probe.touchpadEnded() }
            )
            .accessibilityLabel(L10n.string("pad.a11y"))
            .accessibilityIdentifier("mouse-touchpad")
            .overlay(alignment: .top) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(probe.mouseEnabled ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(probe.inputStatus)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .allowsHitTesting(false)
                    Spacer(minLength: 0)
                    Button { showSettings = true } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("pad-settings")
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 2) {
                    if !probe.lastTypeStatus.isEmpty {
                        Text(probe.lastTypeStatus)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    }
                    Button {
                        if probe.keyboardBusy {
                            probe.cancelTyping()
                        } else if !dictationPresented {
                            startDictation()
                        }
                    } label: {
                        Image(systemName: dictationButtonImage)
                            .font(.title3.weight(.semibold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(Circle().fill(probe.keyboardBusy ? Color.red : Color.orange))
                    .disabled(dictationPresented && !probe.keyboardBusy)
                    .accessibilityLabel(dictationButtonTitle)
                    .accessibilityIdentifier(probe.keyboardBusy ? "dictation-cancel" : "dictation-button")
                    .accessibilityHint(probe.keyboardBusy ? L10n.string("dictation.cancel_hint") : L10n.string("dictation.hint"))
                }
                .padding(.bottom, 1)
            }
            .ignoresSafeArea(edges: .bottom)
        .onAppear { probe.setInputSceneActive(scenePhase == .active) }
        .onChange(of: inputOverlayVisible) { _, blocked in probe.setInputUIBlocked(blocked) }
        .onChange(of: scenePhase) { _, phase in probe.setInputSceneActive(phase == .active) }
        .onDisappear { probe.setInputSceneActive(false) }
        .task {
            probe.setInputSceneActive(scenePhase == .active)
            if ProcessInfo.processInfo.arguments.contains("--r2-probe") {
                _ = RuntimeEnumerator.runProbe { logStore.info($0) }
            }
            probe.prepareMacTouchpad()
            logStore.info("Large pad + dictation UI ready; auto-arm when Mac subscribed")
            #if targetEnvironment(simulator)
            await runSimulatorCheck()
            #endif
        }
        .sheet(isPresented: $showSettings) {
            PadSettingsSheet()
                .environmentObject(probe)
        }
    }

    #if targetEnvironment(simulator)
    private func runSimulatorCheck() async {
        guard !simulatorCheckRan else { return }
        simulatorCheckRan = true
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--simulator-text-entry") || args.contains("--simulator-sample-preview") else { return }
        try? await Task.sleep(for: .seconds(1))
        if args.contains("--simulator-text-entry") {
            logStore.info("SIMULATOR ONLY: invoking real system text entry; no ASR success implied")
            startDictation()
        } else {
            logStore.info("SIMULATOR ONLY: synthetic acceptDictation; not speech recognition")
            probe.acceptDictation("SIMULATOR SAMPLE — not speech")
        }
    }
    #endif

    private var dictationButtonTitle: String {
        if probe.keyboardBusy { return L10n.string("dictation.cancel") }
        if dictationPresented { return L10n.string("dictation.listening") }
        return L10n.string("dictation.button")
    }

    private var dictationButtonImage: String {
        probe.keyboardBusy ? "xmark.circle.fill" : "mic.fill"
    }


    /// Pull the first transcript without logging plaintext. Accept String or NSString.
    private static func dictationString(from results: [Any]?) -> String? {
        guard let first = results?.first else { return nil }
        let text: String
        if let value = first as? String {
            text = value
        } else if let value = first as? NSString {
            text = value as String
        } else {
            LogStore.shared.warn("Dictation result ignored; unexpected type")
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func startDictation() {
        guard let controller = WKApplication.shared().visibleInterfaceController else {
            logStore.warn("Dictation unavailable: no visible interface controller")
            return
        }
        logStore.info("Voice text entry requested; system selects initial input method")
        dictationPresented = true
        probe.setInputUIBlocked(true)
        // Captured text is typed into the Mac when possible. The Watch does not show it.
        controller.presentTextInputController(withSuggestions: nil, allowedInputMode: .plain) { results in
            Task { @MainActor in
                // Unblock and keep the input scene active before typing. The
                // system sheet often leaves scenePhase inactive in this
                // callback, which previously cancelled or blocked the send.
                dictationPresented = false
                probe.setInputUIBlocked(showSettings)
                probe.setInputSceneActive(true)
                guard let text = Self.dictationString(from: results) else {
                    LogStore.shared.info("Dictation canceled or empty")
                    return
                }
                PeripheralProbe.shared.acceptDictation(text)
            }
        }
    }
}

struct PadSettingsSheet: View {
    @EnvironmentObject private var probe: PeripheralProbe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.string("settings.title")).font(.headline)
                Toggle(L10n.string("settings.pause_input"), isOn: Binding(
                    get: { probe.inputPausedByUser },
                    set: { probe.setInputPaused($0) }
                ))
                Toggle(L10n.string("settings.english_keyboard"), isOn: Binding(
                    get: { probe.keyboardFeatureEnabled },
                    set: { probe.setKeyboardFeatureEnabled($0) }
                ))
                Text(L10n.string("settings.dictation_help"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(L10n.string("settings.keyboard_help"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if probe.keyboardBusy {
                    Button(L10n.string("settings.cancel_keyboard")) { probe.cancelTyping() }
                }
                Text(probe.inputStatus).font(.caption2)
                Button(L10n.string("settings.done")) { dismiss() }
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}


@MainActor
final class PhoneBridge: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneBridge()
    private var lastCommand: String?
    private(set) var matrixTask: Task<Void, Never>?

    private func acceptCommand(_ payload: [String: Any]) {
        guard let command = payload["type"] as? String, ["r4-matrix", "r4-baseline"].contains(command), let token = payload["token"] as? String else { return }
        guard lastCommand != token, matrixTask == nil else {
            LogStore.shared.warn("COMMAND duplicate/busy token=\(token)")
            return
        }
        lastCommand = token
        LogStore.shared.step("COMMAND accepted token=\(token) appState=\(WKApplication.shared().applicationState.rawValue)")
        matrixTask = Task { @MainActor in
            if command == "r4-baseline" {
                let restored = await PeripheralProbe.shared.restoreDiagnosticBaseline()
                LogStore.shared.info("BASELINE restoration confirmed=\(restored)")
            } else {
                await PeripheralProbe.shared.runDiagnosticMatrix()
            }
            self.matrixTask = nil
            self.sendLog(LogStore.shared.exportText())
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.acceptCommand(message)
            replyHandler(["received": true, "token": message["token"] as? String ?? ""])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.acceptCommand(userInfo) }
    }

    func finishBackgroundDelivery() async {
        for _ in 0..<5 {
            if let task = matrixTask { await task.value; return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            if let task = matrixTask { await task.value; return }
            if WCSession.default.activationState == .activated && !WCSession.default.hasContentPending { return }
        }
    }

    @Published var lastExportStatus = ""

    func activate() {
        guard WCSession.isSupported() else {
            lastExportStatus = "WCSession unsupported"
            return
        }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendLog(_ text: String) {
        guard WCSession.default.activationState == .activated else {
            lastExportStatus = "session not active"
            LogStore.shared.warn("WCSession not active; cannot export")
            return
        }
        let payload: [String: Any] = [
            "type": "r1-log",
            "text": text,
            "ts": Date().timeIntervalSince1970,
        ]
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: { _ in
                Task { @MainActor in
                    self.lastExportStatus = "sent via message"
                    LogStore.shared.info("Log exported to iPhone (message)")
                }
            }, errorHandler: { error in
                Task { @MainActor in
                    self.transferLog(payload)
                    LogStore.shared.warn("sendMessage failed: \(error.localizedDescription); fallback transfer")
                }
            })
        } else {
            transferLog(payload)
        }
    }

    private func transferLog(_ payload: [String: Any]) {
        WCSession.default.transferUserInfo(payload)
        lastExportStatus = "queued transferUserInfo"
        LogStore.shared.info("Log queued via transferUserInfo")
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error {
                LogStore.shared.warn("WCSession activate error: \(error.localizedDescription)")
            } else {
                LogStore.shared.info("WCSession state=\(activationState.rawValue)")
            }
        }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}


@MainActor
final class WatchBackgroundDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        LogStore.shared.info("Application delegate launched state=\(WKApplication.shared().applicationState.rawValue)")
        PhoneBridge.shared.activate()
        // Do not wait for ContentView.task — install/relaunch often leaves the process
        // backgrounded without a scene, which previously skipped HID advertising entirely.
        Task { @MainActor in
            PeripheralProbe.shared.prepareMacTouchpad()
            LogStore.shared.info("Launch-path prepareMacTouchpad requested")
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            LogStore.shared.info("Background task type=\(String(describing: type(of: task)))")
            if task is WKWatchConnectivityRefreshBackgroundTask {
                LogStore.shared.info("WatchConnectivity background delivery task")
                Task { @MainActor in
                    await PhoneBridge.shared.finishBackgroundDelivery()
                    LogStore.shared.info("WatchConnectivity background delivery completing")
                    task.setTaskCompletedWithSnapshot(false)
                }
            } else {
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
