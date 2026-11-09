# 诊断渠道盘点（2026-11-09 21:41–21:44 HKT）

目标：定位 **iPhone 系统**对 HID 的发现/拒绝阶段；优先既有日志与短有界公开工具。  
约束：无凭证、无内部 API、无关 SIP 安装、无全机高频/大 sysdiagnose 压盘；不解绑/不位移。  
`standard128-dynamic` 已恢复广播。

## 渠道可行性

| 渠道 | 状态 | 能证明什么 | 不能证明什么 |
| -- | -- | -- | -- |
| Watch App `watchhid-r1.log` | 可用 | ATT 读/订阅 central 身份 | 系统发现阶段、空口 PDU |
| Mac `/usr/bin/log`（bluetoothd 谓词，短窗） | **可用、已做 25s** | Mac 侧对同设备的扫描/标志 | **≠ iPhone 空口/系统日志** |
| 既有 `build/diagnostics/r4/bluetooth-hid.log` | 可用（11-08） | 历史 Mac HID/_HID_SERVICE_ 判定 | 非当前、非 iPhone |
| PacketLogger.app | **未安装**（Xcode Additional Tools） | Mac HCI/ATT 原始帧（若启用） | 不能当 iPhone 空口 |
| bluetoothd PacketLogger.HCI | 日志显示 HID/liveHCI **disabled** | — | 未启用抓包 |
| `devicectl device sysdiagnose` | dry-run → **DiagnoseError 0** + 隐私声明 | — | 本机当前不可用；且完整采集体积大，本轮不做 |
| idevicesyslog / libimobiledevice | 未装 | — | — |
| iPhone 进程列表 | 可用 | `bluetoothd` 在跑 | 无日志内容 |
| 无差别广告扫描 | **不做**（按指令） | — | — |

## 比继续 GATT 变体更有信息量的证据

### A. 实时 Mac 25s 流（dynamic 广播中，F7 已订 Report）— **仅 Mac**

文件：`build/diagnostics/r4/diag-channels/mac-stream-25s.txt`

- 同 PhysicalDeviceUniqueID **`492F1BD4-…`** 被标为 **`Md Watch7,5`**，匹配 **Apple MFG** `AMfD <4c 00 10 05 …>`（Continuity/厂商数据路径），**不是**以 “Watch Mouse” 本地名命中。
- 发现标志在 **`NearbyInfo`** 与 **`NearbyInfo BLEHID`** 间切换；存在 SameAccount/HIDGood 相关行。
- 同时 Watch 日志：`standard128-dynamic` + **仅 F7 Report 订阅**。
- 本窗流式谓词命中里 **没有** 实质 “Watch Mouse” 事件行（过滤器说明行除外）。
- **边界**：这是 Mac 系统发现路径观察，**不能**冒充 iPhone 空口或 iPhone 拒绝原因。

### B. 历史 Mac `bluetooth-hid.log`（2026-11-08）

- 多次 `Device <private> does not have _HID_SERVICE_`，时间上紧邻 **`492F1BD4` / Watch7,5** 与 iPhone17,2 的 Monitor Device Found。
- Mac 扫描会话过滤 **UUID `0x1812`（短）**；本摘录 **0** 次 “Watch Mouse”。
- PacketLogger.HCI 配置反复保持 **HID/liveHCI disabled**。
- **边界**：Mac 侧、且部分 `<private>`；表明系统对同账号手表身份可走 “无 `_HID_SERVICE_`” 判定路径，**不等于**已证 App 1812 广告匹配失败，也 **≠** iPhone。

### C. 对「短 1812 广告 vs base128 服务」

- Mac bluetoothd 扫描配置明确带 **`UUIDs: 0x1812`**（短）。darwin-bt-remote 广告亦用短 1812。
- 本轮 **没有** PacketLogger PDU → **不能**用空口证明广告里 16-bit vs 128-bit Service UUID 列表编码，也不能把「无手机订阅」升级为协议差异定论。
- 先前 35s 无手机订阅：**仅限该窗**；不假定手机当时在主动搜 HID。

## 真正剩余验证缺口

1. **iPhone bluetoothd/系统 HID 匹配日志**：当前无可用短窗导出（sysdiagnose 失败；无 idevicesyslog）。  
2. **空口 AD/ATT PDU**（短 1812 vs 完整 base128）：需 PacketLogger（或等价公开 HCI 工具）；现未装；装后也是 **Mac 空口**，仍非 iPhone 射频视角。  
3. **手机是否在窗内主动做 HID 主机发现**：需用户前台辅助触控/蓝牙页或系统日志佐证，不能用后台静默窗排除协议问题。

## 一次用户动作准备方案（仅当要补缺口时整组执行）

**目的**：拿到 iPhone 侧是否出现 HID 服务发现/忽略的直接线索（或确认 Console 可见性）。

1. 保持手表 WatchHID 前台 **Advertising**（`standard128-dynamic`；勿点右移）。  
2. Mac 打开 **控制台.app** → 左侧选中 **ZY的iPhone**（USB 已连）→ 搜索/谓词包含 `bluetoothd` 与 `HID` / `1812`（不要开全机无限 Debug）。  
3. iPhone 解锁 → **设置 → 辅助功能 → 触控 → 辅助触控** 保持开启并停留在该页约 30–60s（制造系统关注指针设备的合理窗）。  
4. 说一声「Console 已开」或粘贴/保存 Console 中与 Watch/HID/1812 相关的几行；由我对照 Watch 日志 central。  
5. **可选（Mac 空口，非 iPhone）**：从 Apple Developer 下载 *Additional Tools for Xcode* 安装 **PacketLogger**（无需关 SIP）→ 仅启短时 HCI → 抓 AD 里 Service UUID 编码；明确标注 Mac 侧。

不做：解绑、重置 BT、全量 sysdiagnose、改系统安全、发位移/点击。


## Update — iPhone idevicesyslog（21:47 HKT）

- Installed `libimobiledevice` via Homebrew (small bottles). Pair validate OK for UDID `[PHONE-UDID]`.
- Bounded capture succeeded: `build/diagnostics/r4/iphone-syslog/` (ANALYSIS.md).
- Headline: iPhone ACL to Watch `98:FE:E1:C1:53:39` then `does not have _HID_SERVICE_`; scans short 0x1812 and can tag other devices Aprc Mouse; no Watch Mouse string this window.
