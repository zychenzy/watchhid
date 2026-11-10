# HOGP / iOS 兼容性窄审计（2026-11-09 21:34–21:39 HKT）

## 来源（真实规范与开源，非印象）

1. Bluetooth SIG HOGP 1.0（HTML）：https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/HOGP_v1.0/out/en/index-en.html  
2. HID Service 规格入口：https://www.bluetooth.com/specifications/specs/hid-service-specification/  
3. 声称可工作的 iOS/macOS HOGP 外设开源 **darwin-bt-remote**（AGPL）：  
   - README：https://github.com/jqssun/darwin-bt-remote  
   - LowEnergy GATT：https://raw.githubusercontent.com/jqssun/darwin-bt-remote/main/BTHIDKit/Sources/BTHIDKit/LowEnergy/GATT.swift  
   - HIDPeripheral：https://raw.githubusercontent.com/jqssun/darwin-bt-remote/main/BTHIDKit/Sources/BTHIDKit/LowEnergy/HIDPeripheral.swift  
4. Punch Through（iOS 发现 HID 后由系统接管，App 不可见 HID）：https://punchthrough.com/ble-human-interface-device-connections-on-ios-and-android/  
5. InpuDeck 文档对短/完整 1812 的观察（非保证）：https://github.com/keefeere/InpuDeck/blob/main/docs/direct-ble-hid.md  

## 本工程 vs HOGP Report Host 设备侧（核对表）

| 项 | HOGP/HID Service | 本工程 dynamic | darwin-bt-remote LE | 备注 |
| -- | -- | -- | -- | -- |
| HID/Battery/DIS 主服务 | M | 有（base128 注册） | 有（base128 注册） | 短 1812 addService → CBError 8（已证） |
| Protocol Mode 2A4E | Report Host O；读=0x01 Report | 读返回 0x01；可写 | 同；+加密权限 | 值正确 |
| Report Map 2A4B | M | 有；dynamic ATT | 静态 value + 加密读 | Mac 需 dynamic 才稳定 ATT |
| Report 2A4D + 2908 | M；Input→notify | Report ID0 / Type Input `0001` | 多 Report+ID；notifyEncryptionRequired | 无 Report ID 合法 |
| HID Information 2A4A | M | `11 01 00 02` | 加密读 | normally-connectable |
| HID Control Point 2A4C | C（Suspend） | WriteWithoutResponse | **仅 .read**（异常，不盲抄） | 我们保留规范写 |
| Boot Mouse 2A33 | Boot Host C；Report Host X | **原无**；hogp-v1 已加 | 有 | |
| PnP ID 2A50 | Report Host M | 有（Apple 0x4C 或 pnpgen） | 有 | pnpgen 已证 Mac 非必需 Apple VID |
| 广告 Service UUID | should 含 HID | dynamic：短 1812 + Appearance | **短 1812 + LocalName，无 Appearance** | |
| 安全 | LE SM1 L2/3；bond | encrypted/hogp-v1 设 encryption-required 标志 | 全树加密权限 | **标志≠已证 SMP** |
| Battery Include / 2907 | 仅当 Map 描述外部特征 | 无（Map 不含 Battery） | Include + External Report Ref | 我们 Map 不含电量→非强制 |

## 「base128 数学等价但系统发现匹配不同」假设

- **服务注册**：短 `1812` 被拒、完整 base128 可注册 — 已证实（R2）。  
- **公开 CBUUID**：`short == full` 且 data 长度 2 vs 16 — 已测。  
- **广告**：darwin 与本工程 dynamic **都用短 1812 广告**；darwin 注释写明 advertising 用短形式。→ **不能**把「广告改完整 128 位」当成与可工作开源对齐的下一步。  
- **特征创建**：本工程多用短字符串创建；darwin 用完整字符串。CoreBluetooth 对 SIG UUID 通常等价；hogp-v1 已改为完整特征 UUID 做对照。  
- **线上 ATT 16/128 编码**：远端 CB 打印不能当 PDU 证据；PacketLogger 未装。仍为未证。

## 已执行有界对照：`standard128-hogp-v1`（21:38–21:39 HKT）

相对 dynamic 的**有意差异**（保留 Mac 配方为独立 case）：

1. 特征/描述符 UUID 用完整 base128 字符串创建  
2. 加入 Boot Mouse Input Report `2A33`（notifyEncryptionRequired）  
3. 加宽 encryption-required（Protocol Mode 读写加密、Control Point 写加密、Battery notifyEncryptionRequired、Report 同 encrypted）  
4. 广告对齐 darwin：仅 LocalName + HID Service UUID，**不请求 Appearance**  
5. 特征顺序靠近 darwin（ControlPoint → ProtocolMode → HIDInfo → BootMouse → ReportMap → Report）  
6. Control Point **仍** WriteWithoutResponse（不盲抄 darwin `.read`）

**实证（手表日志，无 nudge/位移/解绑）**

- hogp-v1：`didAddService` 三服务 OK；广告无 Appearance；**仅** central `F7A703F6`；**仅** Report(`00002A4D-…`) 订阅；**无** Boot Mouse 订阅；**无** 908/新 central。  
- 恢复 dynamic：F7 再订 Report（+Battery）；配方 ATT 路径仍在。  
- 两窗 ioreg 快照均未见稳定 WatchHID 字符串（标签不稳；**不**写成 Continuity 根因）。  
- 证据：`build/diagnostics/r4/hogp/`。

**结论**：在本有界窗，darwin 风格布局/加密加宽/Boot/去 Appearance **未**引出 iPhone（或任何非 Mac）Report/Boot 订阅。拒绝「仅这些布局差即可立刻得到手机系统订阅」；**未**宣称手机永不可能。

## 下一有区分力项（无需立刻找用户）

| 优先级 | 项 | 能区分什么 | 风险 |
| -- | -- | -- | -- |
| 1 | （可选）Battery Include + Report Map External Report Reference（darwin 模式） | 外部电量引用是否影响主机绑定 | 中（改 Map） |
| 2 | 仅当用户确认辅助触控指针是否已可动（一次问） | Continuity 指针 vs 本工程 Report 分流 | 低，需用户 |
| 3 | PacketLogger/空口 PDU（若日后可用） | ATT UUID 16 vs 128 编码 | 工具依赖 |
| — | 不解绑前提下让 Mac 释放 HOGP | 假说 C | **当前禁止** BT 重置 |

idleTimerDisabled 仍未部署（本阶段无需手机前台）。
