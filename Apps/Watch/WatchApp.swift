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
                Label("听写", systemImage: "mic.fill")
                    .font(.caption2.bold())
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(false)
            .accessibilityIdentifier("dictation-button")

            if !probe.lastTypeStatus.isEmpty {
                Text(probe.lastTypeStatus)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .onChange(of: scenePhase) { _, phase in probe.setInputSceneActive(phase == .active) }
        .onDisappear { probe.setInputSceneActive(false) }
        .task {
            probe.setInputSceneActive(scenePhase == .active)
            if ProcessInfo.processInfo.arguments.contains("--r2-probe") {
                _ = RuntimeEnumerator.runProbe { logStore.info($0) }
            }
            probe.prepareMacTouchpad()
            logStore.info("Large pad + dictation UI ready; auto-arm when Mac subscribed")
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

    private func startDictation() {
        guard let controller = WKApplication.shared().visibleInterfaceController else {
            logStore.warn("Dictation unavailable: no visible interface controller")
            return
        }
        // nil suggestions → system tries to open dictation directly (device; Simulator may differ).
        controller.presentTextInputController(withSuggestions: nil, allowedInputMode: .plain) { results in
            Task { @MainActor in
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
                Text("确认发送到 Mac").font(.headline)
                Text("仅英文 ASCII 会经 HID 键盘发送；中文等非 ASCII 会被跳过，不会乱码替换。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(probe.dictationPreview ?? "")
                    .font(.body)
                HStack {
                    Button("取消") {
                        probe.clearDictationPreview()
                        dismiss()
                    }
                    Spacer()
                    Button("发送英文") {
                        if let text = probe.dictationPreview {
                            probe.typeReviewedASCII(text)
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!(probe.keyboardFeatureEnabled && (probe.dictationPreview?.isEmpty == false)))
                }
                if !probe.keyboardFeatureEnabled {
                    Text("请先在设置中打开「英文键盘 HID」（可能需重新订阅，默认关闭以保护鼠标）。")
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
