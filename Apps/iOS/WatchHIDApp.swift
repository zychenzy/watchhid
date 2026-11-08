import SwiftUI
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
                .onAppear { logInbox.activate() }
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
