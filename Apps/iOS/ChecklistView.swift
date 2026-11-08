import SwiftUI

struct ChecklistView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("晚上真机步骤") {
                    Text("1. iPhone 与 Ultra 2 已配对，Mac mini 上 Xcode 能看到两者")
                    Text("2. 打开 WatchHID iOS App → 扫描页点「开始扫描」")
                    Text("3. 在手表打开 WatchHID → 点「开始广播」")
                    Text("4. 看手表状态是否变为 Advertising / 或明确报错 unsupported / UUID not allowed")
                    Text("5. iPhone 扫描列表是否出现 Watch Mouse；nRF Connect 交叉确认")
                    Text("6. 手表点「导出日志到 iPhone」，在「手表日志」页核对")
                    Text("7. 把日志与截图记入立项 Page")
                }
                Section("通过判定") {
                    Text("R1 通过：nRF/本 App 扫到 Watch Mouse 广播")
                    Text("R1 不通过：state=unsupported 或 startAdvertising/addService 明确失败（仍算有效实验结果）")
                }
            }
            .navigationTitle("测试清单")
        }
    }
}
