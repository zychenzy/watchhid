import SwiftUI
import UIKit
import WatchConnectivity

@main
struct WatchHIDApp: App {
    @StateObject private var scanner = BLEScanner()
    @StateObject private var logInbox = WatchLogInbox()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(scanner)
                .environmentObject(logInbox)
                .onAppear {
                    // App-only: keep screen awake during short HID collects. Does not change system auto-lock.
                    UIApplication.shared.isIdleTimerDisabled = true
                    logInbox.activate()
                }
                .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            ScannerView()
                .tabItem { Label("扫描", systemImage: "dot.radiowaves.left.and.right") }
            WatchLogView()
                .tabItem { Label("手表日志", systemImage: "applewatch") }
            ChecklistView()
                .tabItem { Label("清单", systemImage: "checklist") }
        }
    }
}
