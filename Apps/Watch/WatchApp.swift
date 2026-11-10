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
    private var inputOverlayVisible: Bool { showSettings || dictationPresented || probe.dictationPreview != nil }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("触控板").font(.caption.bold())
                Spacer()
                Circle()
                    .fill(probe.mouseEnabled ? Color.green : Color.gray)
                    .frame(width: 7, height: 7)
                Button { showSettings = true } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("pad-settings")
            }
            Text(probe.inputStatus)
                .font(.system(size: 10))
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            RoundedRectangle(cornerRadius: 14)
                .fill(probe.mouseEnabled ? Color.blue.opacity(0.28) : Color.gray.opacity(0.15))
                .overlay {
                    VStack(spacing: 2) {
                        Image(systemName: probe.mouseTouching ? "hand.draw.fill" : "hand.draw")
                        Text(probe.mouseEnabled ? "拖移 · 轻点左键 · 长按右键" : "等待就绪")
                            .font(.system(size: 10))
                            .multilineTextAlignment(.center)
                    }
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, minHeight: 88, maxHeight: .infinity)
                .contentShape(RoundedRectangle(cornerRadius: 14))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            probe.touchpadChanged(x: Double(value.location.x), y: Double(value.location.y))
                        }
                        .onEnded { _ in probe.touchpadEnded() }
                )
                .accessibilityLabel("触控板")
                .accessibilityIdentifier("mouse-touchpad")

            Button {
                startDictation()
            } label: {
                Label("语音听写", systemImage: "mic.fill")
                    .font(.caption2.bold())
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(false)
            .accessibilityIdentifier("dictation-button")
            .accessibilityHint("若显示键盘，点右下角输入方式，再选麦克风。")

            if !probe.lastTypeStatus.isEmpty {
                Text(probe.lastTypeStatus)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
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
        .sheet(isPresented: Binding(
            get: { probe.dictationPreview != nil },
            set: { if !$0 { probe.clearDictationPreview() } }
        )) {
            DictationReviewSheet()
                .environmentObject(probe)
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
            logStore.info("SIMULATOR ONLY: synthetic String preview; not speech recognition")
            probe.presentDictationReview(text: "SIMULATOR SAMPLE — not speech")
            if args.contains("--simulator-dismiss-preview") {
                try? await Task.sleep(for: .seconds(3))
                probe.clearDictationPreview()
                logStore.info("SIMULATOR ONLY: programmatic preview dismissal; touch input not simulated")
            }
        }
    }
    #endif

    private func startDictation() {
        guard let controller = WKApplication.shared().visibleInterfaceController else {
            logStore.warn("Dictation unavailable: no visible interface controller")
            return
        }
        logStore.info("Voice text entry requested; system selects initial input method")
        dictationPresented = true
        probe.setInputUIBlocked(true)
        // System text entry returns a String; nothing is typed into the Mac automatically.
        controller.presentTextInputController(withSuggestions: nil, allowedInputMode: .plain) { results in
            Task { @MainActor in
                defer {
                    dictationPresented = false
                    probe.setInputUIBlocked(showSettings || probe.dictationPreview != nil)
                    probe.setInputSceneActive(scenePhase == .active)
                }
                guard let text = results?.first as? String else {
                    LogStore.shared.info("Dictation canceled or empty")
                    return
                }
                PeripheralProbe.shared.presentDictationReview(text: text)
            }
        }
    }
}

struct DictationReviewSheet: View {
    @EnvironmentObject private var probe: PeripheralProbe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("听写结果").font(.headline)
                Text("文字仅保留在手表，不会自动输入 Mac。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(probe.dictationPreview ?? "")
                    .font(.body)
                HStack {
                    Button("完成") {
                        probe.clearDictationPreview()
                        dismiss()
                    }
                    Spacer()
                    if probe.keyboardFeatureEnabled {
                    Button("发送英文") {
                        if let text = probe.dictationPreview {
                            probe.typeReviewedASCII(text)
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(probe.dictationPreview?.isEmpty != false)
                    }
                }
                if !probe.keyboardFeatureEnabled {
                    Text("英文发送仍是实验功能；当前只查看听写文字。")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding()
        }
    }
}

struct PadSettingsSheet: View {
    @EnvironmentObject private var probe: PeripheralProbe
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("设置").font(.headline)
                Toggle("暂停触控输入", isOn: Binding(
                    get: { probe.inputPausedByUser },
                    set: { probe.setInputPaused($0) }
                ))
                Toggle("英文键盘 HID（实验）", isOn: Binding(
                    get: { probe.keyboardFeatureEnabled },
                    set: { probe.setKeyboardFeatureEnabled($0) }
                ))
                Text("语音听写：若系统先显示键盘，点右下角输入方式，再选麦克风；说完点 Done 查看文字。不会自动输入 Mac。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("打开键盘会换成鼠标+键盘复合描述符，可能需 Mac 重新枚举。关闭即回滚基线鼠标图。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if probe.keyboardBusy {
                    Button("取消键盘发送") { probe.cancelTyping() }
                }
                Text(probe.inputStatus).font(.caption2)
                Button("完成") { dismiss() }
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
