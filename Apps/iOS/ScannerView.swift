import SwiftUI

struct ScannerView: View {
    @EnvironmentObject private var scanner: BLEScanner

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(scanner.stateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Toggle("只显示 Watch Mouse / HID 0x1812", isOn: $scanner.filterWatchMouseOnly)

                HStack {
                    Button(scanner.isScanning ? "停止扫描" : "开始扫描") {
                        scanner.isScanning ? scanner.stop() : scanner.start()
                    }
                    .buttonStyle(.borderedProminent)
                }

                List(scanner.peripherals) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name).font(.headline)
                        Text("RSSI \(item.rssi) · \(item.id.uuidString.prefix(8))…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let appearance = item.appearance {
                            Text("Appearance \(appearance)")
                                .font(.caption2)
                        }
                        if !item.serviceUUIDs.isEmpty {
                            Text("Services: \(item.serviceUUIDs.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("BLE 扫描")
        }
    }
}
