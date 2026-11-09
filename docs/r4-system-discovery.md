# R4 系统列表不可见：实测收敛

## 用户现象
用户确认iPhone系统蓝牙无Watch Mouse，仅原ZY的Apple Watch；另一台此前未手动配对的Mac也没有Watch Mouse。不要求重复扫描/截图，不解除原配对。

## 系统层新证据
- Mac mini正常system_profiler显示既有名ZY的Apple Watch，Connected，Services HID BLE；对应ioreg节点Transport Bluetooth Low Energy、ModelNumber Watch7,5、PrimaryUsagePage1/PrimaryUsage2、MaxInputReportSize4，ReportDescriptor与本工程完全相同，并有AppleUserHIDEventDriver及WindowServer客户端。这是系统曾建立鼠标节点的证据，不是CoreBluetooth扫描/订阅计数推断，也不是改用Mac替代iPhone目标。
- bluetoothd正常日志把相同设备标为SameAccount、Hidden、BLEPaired、CloudPaired、HIDGoodBehavior。此前未手动配对不等于系统没有CloudPaired身份；不能据此要求重配或保证会新增Watch Mouse一行。iPhone是否相同隐藏逻辑未取到日志，不下定论。
- 终止自有旧scanner PID8605，其余临时scanner均限时结束；新测试全部--no-notify。切custom后Watch鼠标IOHID节点消失；再次full发布有Report订阅，但节点未稳定恢复。当前仅确认系统节点曾成功出现，不宣称Mac鼠标使用或iPhone通过。

## UUID/描述符边界
- Mac及iPhone远端CoreBluetooth均返回完整1812服务data16字节（0000181200001000800000805F9B34FB），特征2A4E/2A4B/2A4D/2A4A/2A4C data2字节。不能把显示成1812当作ATT线上16位编码证据。
- Report可发现2902和2908；Report Reference实际读到0001（无Report ID的Input）；ProtocolMode/ControlPoint自动出现2900扩展属性。ReportMap三键+padding+相对X/Y/滚轮，总输入4字节；HIDInfo11010002，flags2只表示normally-connectable。ProtocolMode/ControlPoint尚无写处理，BootMouseInputReport未实现；不能声称完整HOGP合规。
- 当前读取无加密权限要求；尚无链路加密/SMP验证，已有原生Watch配对不等于本实验已验证所需安全。下一项可用公开NotifyEncryptionRequired/ReadEncryptionRequired对照，不改权限配置或解绑。
- Apple官方CBPeripheral广告文档只支持LocalName与ServiceUUIDs；appearance请求键不受公开保证。扫描未提供本Watch的appearance；没有原始AD/PDU，不能确认0x03C2发出或AD UUID列表具体类型。PacketLogger未安装/不可用，未安装工具或绕开工具读取内部协议。

## ATT242不是已定位根因
- Mac bluetoothd记录ReadLongCharacteristicValueResponse error242，status65535。完整HID的ProtocolMode/Map/Report/Info读取242，而2908读取0001成功。
- 旧自定义服务C901，以及此前未用过的C903只读静态特征也242。因此不能将242简单归因HID保留过滤或仅旧UUID缓存。Watch日志没有对应动态读回调，具体失败层仍待动态值对照。
- 新增匹配C903 static/dynamic显式case；static运行并得到242，dynamic正常launch被系统拒绝，不能填造对照结果。手机新增显式--connect-target，用公开API连接目标、发现服务/特征；连接成功，但系统鼠标名仅CD-MX Anywhere3，不是Watch，不能按count1算通过。

## 当前阻塞及下一步
- Watch仍connected/paired、开发者模式Enabled；lockState passcodeRequired=false、unlockedSinceBoot=true，不能编造PIN锁屏原因。
- 两次正常launch被IOSSHLMainWorkspace拒绝：Navigation away from clock is not allowed due to one or more active system states。截图全黑，WatchHID进程不在；不能称当前仍在广播。未尝试绕过系统状态。
- 需要本人一次唤醒手表并在正常界面打开WatchHID。随后执行人自主恢复full正对照、完成C903动态读取与加密安全对照、监测iPhone是否新建实际Watch系统鼠标。无需重配/重置或重复提供截图；指针点击/UU均未通过。

参考：
https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/BestPracticesForSettingUpYourIOSDeviceAsAPeripheral/BestPracticesForSettingUpYourIOSDeviceAsAPeripheral.html
https://www.bluetooth.com/specifications/specs/hid-over-gatt-profile-1-0/


## 唤醒后的续测（以上为先前阶段快照）
用户确实打开后实见PID575，正常CLI可重新启动。custom-fresh-dynamic读01/error=nil且有Watch ATT回调；同C903的static→dynamic→static三轮也都01/error=nil。因此静态缓存不是242必然根因，不再以旧结果作该推论。
随后显示状态明确backlight off，前台及--no-activate均被相同系统状态拒绝；passcodeRequired=false，无WatchHID进程。生命周期/系统状态是优先对照，不声称已经证明242只由屏幕状态造成。
已安装standard128-dynamic与standard128-encrypted显式case：前者静态只读数据改动态响应，后者再加SDK公开加密权限/通知条件；尚未运行，不写加密通过。增加scenePhase持久化日志、读取central关联和iPhone串行HID只读验证；签名generic与Simulator均构建通过。
已备好scripts/r4_matrix.py，下一次持续亮屏约45秒直接执行python3 scripts/r4_matrix.py，合并三case采集并恢复baseline，不发移动/点击。无需再次编译或逐项要求用户操作。
R5官方文档要求延长运行类别符合真实用途、active启动，当前鼠标尚无已证实适配类别；未伪装冥想/疗愈/运动或写健康数据：https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions.md


## 23:59 HKT baseline实测及编排修复
已立即运行预备脚本，baseline在Mac与iPhone均成功读取ProtocolMode01、52字节ReportMap、Report00000000、HIDInfo11010002，均error=nil；Mac读Reference0001。系统IOHID节点再次复现，且Manufacturer=WatchHID、ModelNumber=Ultra2-R1，证明本工程DeviceInfo和ReportMap由Mac系统实际解析。手机GCMouse只有CD-MX Anywhere3，不是Watch。
两端串行读取时间分别关联Watch central908CDCF7…（iPhone）及F7A703F6…（Mac）；订阅Report的是后者。自有Mac测试客户端--no-notify，不能把订阅1写成iPhone通过；central本身是主机标识，不是唯一进程。
旧脚本baseline后先终止Watch再启动dynamic，被系统状态拒绝，整套矩阵未完成，未恢复baseline。此处是编排设计不合理，不能再归咎Z没打开或要求不断延长唤醒。
已修为一次启动--r1-matrix，同进程每12秒切baseline/dynamic/encrypted，最后恢复baseline；双方处理ServicesChanged，Mac持续监听44秒，必须核对本轮三阶段及complete标记。取消时只记aborted，不能假报complete。最新版签名及Simulator均构建成功，两端已安装；首次启动仍被原系统状态阻塞，加密及单进程全矩阵尚未运行。
下一次只需允许首次正常激活App，直接python3 scripts/r4_matrix.py，不再编译、逐case重启或要求调唤醒时长；无移动/点击。iPhone截图可见床形专注图标，但尚无证据证明它导致Watch启动拒绝，未改变专注/安全设置。


## WatchConnectivity matrix and lifecycle evidence

The former argv entry did not reach a running Watch process. The current runner sends an explicit, tokenized command through the public WatchConnectivity session; it never launches or terminates the Watch App. The iPhone retrieves the previously verified peripheral identifier through public CoreBluetooth, which is not advertisement evidence.

00:27:32–00:27:42 HKT: token 80c0fd9e-6d8d-4044-b244-6e30bdf869d9 completed baseline/dynamic/encrypted in one process. Each case registered all three full-base-128 services and received successful advertising callbacks. Restoration now awaits the real advertising callback before completing the background task; it succeeded. A separate short baseline command completed in about 0.4s. No nonzero movement/click reports were sent.

Fresh iPhone read windows: baseline 10 failures, dynamic 5, encrypted 5, restored baseline 5; all ATT242, no successful values. Mac: 86 ATT242 and 2 invalid handles during service changes, no successful values. Windows are client timestamp associations, not raw ATT captures. Watch logged no application ATT read callback during this matrix. Current iPhone system mice remain CD-MX Anywhere3 only; current Mac IOHID snapshot has no WatchHID node. Historical foreground baseline read success and Mac recognition remain separate evidence. Encrypted registration is not successful encrypted reading, pairing, or iPhone HID acceptance.

Downloaded actual crash reports: 00:17:11 HKT CAROUSEL WatchConnectivity wall-time exhaustion 15s; 00:19:24 HKT scene-create exhaustion 25s. Matching UUID A6D4E66E-4821-36A1-9811-7B37ABC56621 symbolicates to LogEntry.line.getter (LogEntry.swift:19), called by SwiftUI log rendering. Background log rendering was reduced, but cold-start timing problems subsequently recurred; this is not a proven complete watchdog fix. Signed device and unsigned Simulator builds succeeded.

Normal foreground activation is still denied by IOSSHLMainWorkspace: "Navigation away from clock is not allowed due to one or more active system states". The next discriminating test is foreground versus background ATT callback/read timing, not another UUID rewrite or claim that same-account filtering is proven. No security changes, unpairing, fake workout, raw private IPC, cloud development, or remote push were used.


## 2026-11-09 19:32–19:41 HKT foreground/background ATT

Devices connected; WatchHID launched to Idle then Advertising. Foreground appState=0: iPhone and Mac read Protocol/Map/Report/HIDInfo successfully with Watch ATT read callbacks. Cold WatchConnectivity background wake (~13s to poweredOn) produced advertising but zero ATT read callbacks and client ATT242 on both hosts. Sync CB callback-queue respond was installed; cold background still failed, so MainActor hop was not a sufficient root cause.

Warm process matrix completed baseline/dynamic/encrypted with MATRIX complete while appState logged as 1 (inactive) on some reads that still returned result=0; iPhone read windows at 19:40:53/56/59/41:02 HKT each got four successful values. This does not prove iPhone system HID, AssistiveTouch, or UU. GCMouse remained CD-MX (+ CoreDevice gesture). No WatchHID IOHID node in this session.
