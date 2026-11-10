# iPhone vs Mac HID 识别差异（实证 / 推测分开）

## Encrypted contrast (2026-11-09 21:28 HKT)

Bounded `standard128-encrypted` vs `standard128-dynamic` on installed Watch build (no rebuild, no nudge/move, no BT reset).

- Source: encrypted sets Report/Map/Info `readEncryptionRequired` (perm 0x04) and Report `notifyEncryptionRequired` (prop 0x100). Registration/read/subscribe success is **not** SMP proof and **not** iPhone system HID pass.
- Watch logs (windows ~12s + ~81s encrypted): only central `F7A703F6` (Mac). Report subscribe only F7. No `908CDCF7`, no new/non-Mac Report subscriber.
- Historical corpus: all Report subscribes are F7; 908 reads only.
- Rejects: “encryption-required flags alone immediately produce iPhone system Report subscribe” in this setup. Does **not** claim iPhone can never subscribe.
- Mac IOHID after first encrypted window still showed WatchHID/Ultra2-R1 / 492F; later snapshots lost the string while F7 still subscribed — label instability ≠ Continuity root-cause proof.
- Artifacts: `build/diagnostics/r4/encrypted/CONTRAST.md`.


## 已证实（本仓库日志 + Mac IOHID）

1. **Mac 可作为本工程 HOGP 主机**  
   `standard128-dynamic` 下系统 central `F7A703F6…` 读取 DIS/ReportMap 并 **ATT subscribed Report**；ioreg 出现 Manufacturer=`WatchHID`、ModelNumber=`Ultra2-R1`；`--r1-nudge` 产生 IOHID `00140000` 且紧窗光标 `dx≈20`。

2. **iPhone App 可作为 GATT 客户端读 HID 特征**  
   central `908CDCF7…` 历史成功读 `2A4E/2A4B/2A4D/2A4A`（非系统 HID 通过）。

3. **全采样手表日志中，Report CCCD 订阅者只有 Mac**  
   对 `build/diagnostics/r4/**/*watch*.log` 抽样：`ATT subscribed Report` 的 central **从未**出现非 `F7A703F6…`。  
   → **未见 iPhone 物理 central 在本工程路径订 Report**（至少在已保存日志范围内）。CBCentral UUID 不能区分同一手机内的 App 与系统进程，不能要求系统另出现一个 UUID。

4. **辅助触控开启后（21:17 HKT）**  
   再启 dynamic 广播后仍仅 Mac 订 Report；iPhone App 扫描可见广告；GCMouse 无 Watch —— GCMouse **不能**单独否定辅助触控。

5. **短 UUID `1812` 在 watchOS 上 addService → code 8；完整 base-128 形式可注册**（R2/R3 已证）。远端 CB 打印成 1812 **不等于**线上一定是 16-bit ATT 编码。

6. **Mac 系统蓝牙列表可不出现「Watch Mouse」**  
   同地址 Continuity/SameAccount 身份可显示为「ZY的Apple Watch」+ HID BLE（Hidden/CloudPaired 等，见既有 bluetoothd 摘录）。列表无名 ≠ Mac HOGP 失败。

7. **辅助触控「ZY的Apple Watch 已连接」**  
   实证：列表项存在且用户刚开辅助触控。  
   **未证实**：该连接消费的是本 App 的 1812 Report（本工程回调未见 iPhone central 订 Report）。

## 公开资料（外部，非本机新测）

- Apple：AssistiveTouch 可接蓝牙指针设备（[support 111775](https://support.apple.com/en-us/111775)）。
- Punch Through：iOS 发现 HID GATT 后由 **系统**接管；第三方 App 通常看不到 HID profile（[文章](https://punchthrough.com/ble-human-interface-device-connections-on-ios-and-android/)）。这解释「App 能读特征 / 系统订 Report」在角色上的分裂，**不能**直接证明 iPhone 永远不会对本 Watch 外设做 HOGP。
- 历史 StackOverflow/DTS：iOS **App 作外设**发布 `0x1812` 常被拒（code 8）。本项目是 **watchOS 外设 → Mac/iPhone 主机**，且已用 base-128 在 Mac 上走通，故「iOS 不能当 HID 外设」**不**等价于「iPhone 不能当本 Watch 的 HID 主机」。
- Mobile Mouse 等：Watch 控制 Mac/iPad 多为 **配套 App 通道**，不是 Watch 对 iPhone 发 BLE HOGP 的同构证明。

## 当前最佳假设（标明为推测）

| 假设 | 若真则含义 | 如何证伪（尚未做） |
| --- | --- | --- |
| A. iPhone 对同账号 Watch 优先走 Continuity，不把本 App HOGP 升为第二系统鼠标 | 辅助触控里「ZY的Apple Watch」≠ 本工程 Report 通路 | 在**不**解绑前提下，确认 Continuity 指针是否已可动；同时 Watch 日志仍无 iPhone Report 订阅 |
| B. iPhone HOGP 主机需要加密/bonding，而当前 dynamic 特征无 ReadEncryptionRequired | 仅明文可读不够系统接管 | 有界跑 `standard128-encrypted`，看是否出现**新** iPhone central 订 Report（Mac 配方保留） |
| C. Mac 已占用同 BD_ADDR 的 HOGP Report 主机角色，阻碍 iPhone 再订 | 需 Mac 侧释放主机而无解绑 | 需可逆、不重置 BT 的实验设计；当前**禁止**解绑/重启 bluetoothd |
| D. PnP Apple VID `0x004C` 促使系统并入 Apple 身份 | 改非 Apple VID 后 Mac/iPhone 行为变化 | Mac 单机改 PnP 对照（可逆）；iPhone 仍看 Report 订阅 central |

## 工程准备（已做 / 待装）

- iOS App：`isIdleTimerDisabled = true`（仅本 App 前台，**不**改系统自动锁屏）——源码已加，**待**下次低负载安装后生效。
- HID Information 注释改为 flags=`0x02` 仅 normally-connectable。
- **不**再把「重复广告扫描 / 重复 GATT 四特征读」当作 iPhone HID 通过条件。

## 保留的 Mac 成功配方

`CLI --r1-start --r1-case=standard128-dynamic` → F7 读 DIS+ReportMap → IOHID WatchHID/Ultra2-R1 →（可选）`--r1-nudge` → `00140000` + 光标 dx≈20。无点击。

## PnP 对照补充（21:25 HKT）

- `standard128-dynamic-pnpgen`：Mac IOHID VendorID 变为 **65535**，仍 Manufacturer=WatchHID，F7 订 Report。  
- 切回 `standard128-dynamic` 后短暂出现同一 `PhysicalDeviceUniqueID=492F…` 节点显示 **Manufacturer=Apple Inc. / ModelNumber=Watch7,5**（Continuity 标签），WatchHID 字符串一度消失。  
- **实证**：同 peripheral UUID 上，系统可在「本工程 DIS 标签」与「Apple Watch Continuity 标签」间切换/并存竞争。  
- **推测**：iPhone 辅助触控「ZY的Apple Watch」更可能挂 Continuity 身份，而非本 App DIS 的 WatchHID 字符串。

### 切回 dynamic 后的节点态（同窗）

- F7 仍订 Report，但 20s 内未再出现 Manufacturer=WatchHID 字符串；中间曾见同 UUID 标成 Apple Inc./Watch7,5。  
- 末次 relaunch 日志里 F7 **先订 Report、未见本次 2A4B Report Map 重读**（与早先稳定复现窗不同）。  
- **实证**：Mac HOGP 节点标签/描述符刷新不稳定，存在 Continuity 标签覆盖；**不**把此刻 WatchHID 字符串缺失写成 Mac 配方永久失效。成功配方仍以曾证 IOHID+光标为准。
