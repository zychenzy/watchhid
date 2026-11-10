# R1 真机对照结果

环境：Ultra 2 / watchOS27.2；Mac mini Xcode27.2；iPhone16 Pro Max iOS27.2。观测时间23:11–23:14 HKT。

| case | 注册 | 广播API | Mac空口 | iPhone扫描 |
|---|---|---|---|---|
| standard | 1812/180F/180A全部CBErrorDomain code8 | OK,true | Watch Mouse+1812 | 同步收到Watch Mouse+1812 |
| custom | A7B10001-7E42-4C63-9D17-B5A0F055C901注册OK | OK,true | 收到自定义UUID（含明确UUID过滤扫描） | 收到同一设备自定义UUID |
| custom-appearance | 同上注册OK | OK,true | 收到自定义UUID；扫描字典未提供appearance | 接收器持续扫描，去重日志不区分本case |
| name-only | 不注册服务 | OK,true | Watch Mouse，无服务UUID | Watch Mouse，无服务UUID |

正常CoreBluetooth连接与服务发现：standard发现系统180A、Continuity D0611E78-BBB4-4591-A5F8-487910AE4366和9FA480E0-4967-4542-9390-D343DC5D04AE；没有1812/180F。系统既有180A不等于本App注册成功。custom额外发现本App的128位服务及A7B10002特征，读取成功（1字节，无错误）。

结论：手表BLE外设角色、真实广播、自定义GATT服务和外部读取均已证实。主要阻塞为标准HID服务注册，不是“watchOS完全不能当BLE外设”。仅广播1812不会建立HID服务。请求appearance=0x03C2后扫描字典没有该字段，不能据此证明原始空口包一定不含appearance。iPhone系统蓝牙鼠标识别、辅助触控、UU仍未通过。

CLI：watch使用--r1-start及--r1-case=standard/custom/custom-appearance/name-only；phone使用--scan自动启动测试扫描并仅将目标观察写入Documents/watchhid-scan.log。Mac scanner --all，--service=<UUID>为显式过滤；--connect仅连接名为Watch Mouse的目标做GATT发现。未模拟触控。

连接诊断：23:09 HKT工具首次重试就connected；Ethernet en0和Wi-Fi en1都active，默认路由保持en0；23:00后pmset实际Sleep/Wake事件为0；窄范围configd日志只有en10 link-local发布，未见en0/en1断链证据。不能认定掉线根因是网络波动，也不能把工具离线等同于Mac睡眠/物理设备掉线。未改网络。

下一步：保留自定义GATT正对照，进入R2定位标准HID UUID注册的服务端限制及私有发布通道。不可把广播API返回成功或广告含1812写成HID已注册。
