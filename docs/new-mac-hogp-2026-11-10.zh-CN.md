# 新 Mac 加密 HOGP 路径：2026-11-10 实证（北京时间，Asia/Shanghai）

把已经看见的事实，和由此作出的推断分开写。不要打印 UDID、蓝牙地址、描述文件设备列表，或源码里写死的中央标识。不要把配对成功写成指针已经可用。更短的操作说明见 [SETUP.zh-CN.md](SETUP.zh-CN.md)、[RETURN-CHECKLIST.zh-CN.md](RETURN-CHECKLIST.zh-CN.md) 和项目 skill。

## 已证实

### 上午，未加密包（约 11:16）

BTLEServer 读到了 WatchHID 的 Device Information 指纹：Manufacturer 先是 `<private>`，随后是 “Apple Inc.”；当天上午唯一一次 PnP 记录为 `BT / 0x004C / 0x0000 / 0x0001`，与源码默认 `pnpIDBytes` 一致。操作者确认过配对弹窗。随后 BTLEServer 拒绝创建 HID，日志是 `Not creating HID device as the link is not encrypted`。这只说明那一次创建被“链路未加密”挡住，不能证明这台电脑上完全不存在任何既有绑定。点过配对确认只是设置步骤，不是 HID 加密已成功。当时没有出现 WatchHID 的 IOHID 节点。

### 加密包安装（11:54）

在能签名的 Mac mini 上构建的 zip（SHA-256 `d38079d7567641f786bb5e8c1b29f444e5c47fa5c5440b61ddf0f87ba013fc94`）使用 `WH_HOGP_ENCRYPTED` / `standard128-encrypted`：给 Report Map 和输入 Report 设置加密读，并给输入 Report 设置加密通知。不要写成这些读/通知特征还要求加密写。Protocol Mode / Control Point 另有各自的写权限，那不是报告描述的读/通知路径。

11:54 在配对 iPhone 与这台 Mac 同一 Wi-Fi 且已解锁、未插 USB 时，无线安装并拉起成功。这只是那一次观察，不代表以后都必须有 iPhone，也不代表已经验证附近没有 iPhone（无线隔离）时仍能安装。拉起后服务被 invalidated；到约 11:56 仍没有新的 HID 初始化，也没有 WatchHID 节点。其他电脑上已经成功的加密 HOGP 绑定不能拷到这台 Mac。本机重新构建才需要签名证书；这台 MacBook 当时没有可用的 Apple Development 身份。描述文件仍有效的预签名包可以在没有本机证书时安装。

### 下午确认配对之前（13:24–13:58）

操作者确认：手表和这台 Mac 上都没有出现配对/确认界面；如果出现，他们会确认。典型循环是：连接后 Manufacturer 常常只有 “Apple Inc.”、没有 PnP，出现 ATT 242，然后 `startAutoPairing=1` / `StartPairing`，对端在约 60 毫秒内返回 Pairing Failed reason=8（蓝牙 SMP 规范里对应 Unspecified Reason，这是对日志数字的规范映射，不是系统打印的英文），再出现 ATT 15，没有可见弹窗。协议栈确实启动了自动配对；对端在确认界面出现之前就中止了。

Manufacturer 只有 “Apple Inc.”、没有 PnP，说明当时至少读到了系统 Apple Watch 的 Device Information。由此推断：那些循环里成功读到的往往不是 WatchHID 的 GATT。残留或冲突的 LE 绑定只是可能，没有被证明。操作者一度看到手表在锁屏；解锁后 WatchHID 不在前台，也没有报错。14:01 重新打开后，屏幕状态是「等待mac系统订阅」，对应源码字符串 `等待 Mac 系统订阅`。

### 重新打开并完成 passkey 确认之后

14:01:27 再次出现 WatchHID GATT 指纹：Manufacturer 先是 “Apple Inc.”，随后第二条 Manufacturer 为 `<private>`，PnP 为 `BT / 0x004C / 0x0000 / 0x0001`，并看到 Report Map `0x2A4B` 和 Report `0x2A4D`。14:01:27.892 `startAutoPairing`；14:01:28.012 出现 Passkey Entry / BluetoothUIServer（即操作者看到的弹窗）。14:01:46 系统接受了 passkey（具体数值已从证据中去掉）。14:01:49.522 `isPairing=1`，加密已启用；14:01:49.582 `smpPairingCompleted status=0`；14:01:49.972 这台 Mac 订阅了 Report `0x2A4D`；14:01:49.976 BTLEServer 启动了 `IOHIDUserDevice`。在 14:00–14:03:50 窗口内：没有 ATT 242、没有 ATT 15、没有 reason=8、没有 “Not creating HID…”。

同一 IOHID 节点上同时具备 Manufacturer=`WatchHID`、ModelNumber=`Ultra2-R1` 以及鼠标/指针 Usage：**仍未出现**。系统确实创建了 HID 鼠标，但身份是系统 Apple Watch：Manufacturer=`Apple Inc.`，ModelNumber=`Watch7,5`，Product=`ZY的Apple Watch`，传输为 Bluetooth Low Energy，报告描述符 52 字节（另有一个类似节点，以及一个描述符长度为 0 的节点）。项目基线 `mouseReportMap` 是 64 字节；52 与 64 不相等，所以这个 IOHID 设备并不是“只是把项目基线报告描述换了个名字”。不要声称已经解析出这 52 字节的内容。`system_profiler` 里已连接的 “ZY的Apple Watch” / HID BLE **不是**项目成功标准。

随后操作者在安全桌面上短滑并轻点：指针没有移动；手表仍显示 `等待 Mac 系统订阅`。不要声称指针已经移动。这台 Mac 上的配对和加密现在有实证；WatchHID 身份和指针移动还没有。加密路径还不是快速、可靠的成功方案。刚刚完成的绑定不要用重置蓝牙去拆掉。

## 源码事实（与推断分开）

下列内容来自 `Apps/Watch/PeripheralProbe.swift` 和 `Apps/Watch/PeripheralManagerFactory.m`，不是对当天日志的再解释。

- `等待 Mac 系统订阅` 是 `inputStatus`：当前界面在前台、用户没有暂停、没有弹层挡住，且 `macInputReady` 为假时显示。广告是否成功写在另一个字段 `statusSummary`（例如 `Advertising: Watch Mouse`），不要和订阅状态混为一谈。
- `macInputReady` 为真，当且仅当：探针已在运行、外设管理器是 poweredOn（状态值 5）、已经持有鼠标 Report 特征，并且当前 CCCD 订阅者集合**精确等于**源码里写死的那一个 Mac 中央标识（来自原先那台 mini；不要在文档或聊天里写出这个标识）。键盘就绪对键盘 Report 使用同一条精确匹配规则。
- 日常触控路径（开始触摸、滑动发送、单击、以及输入门打开）都要求 `macInputReady` 为真。`submitMouseReport` 在调用底层通知之前，会再次检查订阅者集合是否精确等于那个写死的中央标识；不满足就跳过发送。
- 底层 `WHUpdateReport` 调用 `updateValue:forCharacteristic:onSubscribedCentrals:` 时，中央参数是 `nil`。按 CoreBluetooth 的惯例，一旦真正发出通知，会发给当时所有已订阅的中央，而不是只发给那个写死的标识。但日常触控路径在集合不等于该标识时根本不会调用它。因此：日常报告**不会**只因为“有任意 Mac 订阅了”就发出去。
- 默认 PnP 使用 Apple 厂商号 `0x004C`。源码注释写的是推测：这个厂商号「可能促使 SameAccount 合并」；非 Apple 厂商号只出现在实验配方 `standard128-dynamic-pnpgen` 里，不是当前加密包的默认值。Device Information 里的制造商/型号即使在加密配方下仍是明文可读，值分别为 `WatchHID` 和 `Ultra2-R1`。

## 推断（不是已证结论）

- 14:01:49.972 这台 Mac 已经订阅了 Report，但手表仍显示 `等待 Mac 系统订阅`。用上面的源码规则可以解释：订阅者集合必须精确等于写死的 mini 中央标识，这台 MacBook 的中央标识通常不会碰巧相同。这是对「状态仍停在等待」的源码层面解释，不是对这台电脑中央标识的实测。
- 指针没有移动的一个有源码依据的主要假说是：输入门没有打开，`submitMouseReport` 跳过了通知。不要把它写成唯一原因。身份是 `Apple Inc.` / `Watch7,5`，以及 52 字节描述符与项目 64 字节基线不一致，即使报告发出去，也可能让系统鼠标不可用或不按项目身份出现。
- BTLEServer 可能把 HID 设备发到了系统 Apple Watch 的 Device Information / Apple 厂商号下面，而不是项目的 `WatchHID` / `Ultra2-R1`。这与源码里对 `0x004C` 的推测性注释一致，也与当天节点身份和描述符长度相符；还不是已经证实的合并机制。

## 下一步

不要立刻重置蓝牙。接受当前实际订阅者作为输入主机的源码修改已在本分支，但尚未签名安装到手表。这台 MacBook 在 2026-11-10 当时没有可用的 Apple Development 身份，所以 11:54 的加密包是在 mini 上签的；以后要在这台电脑上出包，按 [SETUP.zh-CN.md](SETUP.zh-CN.md) 第 4 节在本机为同一开发 Apple ID 创建证书即可，不必回到原先的签名机，也不要拷私钥或吊销其他电脑的证书。装上后再验证 WatchHID 身份和指针移动。若门打开后身份仍不是 `WatchHID` / `Ultra2-R1`，再单独考虑非 Apple PnP 或如何让系统发布项目自己的 Device Information。

## 本机签名身份（2026-11-10 15:36–15:39，北京时间）

Xcode 里当天的 Apple Development 证书已在钥匙串（状态空白），`security find-identity -v -p codesigning` 仍为空，是因为登录/系统钥匙串缺少官方 WWDR G3 中间证书（只有已过期的同名旧 WWDR），不是私钥缺失，也不是需要再创建一张开发证书。从 [Apple PKI](https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer) 下载后执行 `security add-certificates` 写入登录钥匙串时，系统弹出了钥匙串密码/允许提示；在本机确认后，身份变为可用。随后 `./scripts/check-signing-prereqs.sh` 通过，`./scripts/ship-encrypted-hogp.sh`（不加 `--install`）在本机签出 `build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip`（sha256 `c8c48cf1c361fcd5e813fdd314038bd50399375f0d79fa4e6be9455b806ebfde`）。不要把这次密码提示理解成又触发了证书创建。
