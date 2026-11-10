# WatchHID：新 Mac 开发环境 Setup

本文说明如何在一台新 Mac 上安装官方 Xcode、配置签名，以及安装或构建 WatchHID。步骤按官方要求与已核实现象编写；未完成的步骤不会写成已经成功。

主仓库默认留在现有开发机，不必为了安装已签名包而把整个项目再 clone 一份。本地设备标识与 team ID 只放在 gitignore 的 `Config/Developer.xcconfig`、`Config/local_devices.env`，不要写进文档或提交到 git。

## 1. 先分清两件事

- **安装已有签名包**：把已经签好的 watchOS `.app` 装到手表。只要描述文件仍有效，且目标手表 UDID 已在该描述文件中，就不需要从另一台 Mac 拷贝私钥或登录 token。仍需要本机有完整 Xcode/`devicectl`，并且能看到这块手表。
- **在本机重新构建/签名**：用本机 Xcode 登录的 Apple 开发账号签发新的证书和描述文件。不要从其他电脑复制钥匙串私钥。

另外：**这台 Mac 的系统登录 / iCloud 账号，可以和 Xcode 里用于签名的 Apple ID 不是同一个。** 不要为了开发签名去退出或更换 macOS / iCloud 账号。在 Xcode > Settings > Accounts 中额外添加开发用的免费 Apple ID 即可。

运行已经装在手表上的 WatchHID、让它给 Mac 当蓝牙鼠标时，**不需要** Xcode 保持打开，也**不需要** iPhone 通过 USB 接到这台 Mac。

## 2. 官方版本兼容

先看本机系统：

```bash
sw_vers
```

再对照 Apple 官方表格：[SDK and system requirements](https://developer.apple.com/xcode/system-requirements/)。不要按旧印象安装不支持当前 macOS 的 Xcode。

已核实的对应关系（以官方表为准，日期会变）：

| 本机 macOS | 可用的正式版 Xcode | 不要用 |
|---|---|---|
| macOS 27.2 | **Xcode 27.2**（含 watchOS 27.2 / iOS 27.2 / macOS 27.2 SDK）。Xcode 27 / 27.1 也声明支持 macOS 26.6 及更新版本，但应优先与当前系统/SDK 对齐的正式版。 | **Xcode 26.6**：官方只支持 macOS 26.2–26.x，不能装在 macOS 27.2 上。也不要为了本项目去装 Xcode 27.3 beta，除非你明确需要更新的 SDK。 |

设备支持方面，Xcode 27.2 可在 watchOS 10 及更新的真机上安装和调试。下载前确认磁盘空间：App Store 列出的 Xcode 27.2 约 3.1 GB，解压/安装后占用更大，若还要下载 watchOS 模拟器运行时需要再留几 GB。空间紧张时，不要同时开始很大的 macOS 系统更新。

## 3. 安装完整 Xcode

只使用官方来源：

1. **Mac App Store** 中的 Xcode（当前正式版如为 27.2，即可直接装）。可用这台 Mac 现有的 App Store 登录，不必换成开发签名账号，也不必改 iCloud。
2. [Apple Developer 下载](https://developer.apple.com/download/all/?q=Xcode) 中的 `Xcode_27.2.xip`，或用已安装的 `xcodes` 指定版本（例如 `xcodes install 27.2`）。这条路径会要求在官方界面登录 Apple ID；把密码和验证码只打在系统/Apple 自己的输入框里，不要发到聊天或日志。

本机若只有 Command Line Tools，`xcrun devicectl` 可能只是占位提示「请安装 Xcode」，不能列设备或装包。装好完整 Xcode.app 之后再执行：

```bash
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -runFirstLaunch
xcodebuild -version
xcrun devicectl --version
xcrun devicectl list devices
```

`sudo` 和首次许可会弹出系统自己的管理员密码/许可窗口，在本机对话框中确认即可。`xcode-select` 与 first launch 完成前，不要指望 CoreDevice 已经可用。

## 4. 免费账号签名（本机构建时）

若只需安装仍然有效的已签名包，可先跳过本节，见第 6 节。

若要在这台 Mac 上重新 build / sign：

1. 保持当前 macOS / iCloud 登录不变。
2. 打开 Xcode > Settings > Accounts，添加**此前用于本项目的免费 Apple ID（个人 team）**。按系统提示完成登录和双重验证；不要在聊天里发送密码或验证码。
3. 把 `Config/Developer.xcconfig.example` 复制为 gitignore 的 `Config/Developer.xcconfig`，填入该账号在 Xcode 中显示的 `DEVELOPMENT_TEAM`。不要提交这个文件，也不要从别的电脑拷钥匙串私钥。
4. 免费个人 team 的开发描述文件有效期通常约 7 天，过期后需要在本机用同一账号重新签发，而不是迁移旧私钥。

然后按仓库根目录 README 的 signed Watch device build 流程：`xcodegen generate`，再 `xcodebuild` / Xcode Run。`devicectl` 激活不稳定时，优先用 Xcode 直接 Run 到手表。

## 5. 手表 Developer Mode 与开发配对

要在这台新 Mac 上安装或调试 Watch 应用，通常需要：

1. 在 Apple Watch 的「设置 > 隐私与安全性」中打开 **Developer Mode**，按系统要求重启。
2. 手表解锁并靠近这台 Mac。第一次开发配对时，附近的配对 iPhone 可能有帮助，但这不等于以后运行鼠标功能必须插着手机 USB。
3. 手表或 iPhone 上如果出现「信任这台电脑」，在设备上确认。
4. 用 `xcrun devicectl list devices` 确认能看到这块 Watch，且开发者模式为可用状态。

**不要**为了让设备出现或为了修鼠标而去取消配对、重置系统蓝牙或关闭安全防护。

## 6. 安装已有签名包

已签名归档是 watchOS `.app` 的 zip，不是可双击的 Mac 应用。典型位置在原开发机的本地目录 `build/diagnostics/recovery-root/`（该目录已 gitignore，不会随仓库推送）。

安装前在本机检查，不要把描述文件或 UDID 写回 git：

```bash
# zip 里可能带有 AppleDouble 的 ._* 文件，先去掉再校验
ditto -x -k WatchHID-return-home-candidate.zip ./candidate
find ./candidate -name '._*' -delete
codesign --verify --verbose=2 ./candidate/WatchHIDWatchApp.app
python3 scripts/watchhid_scriptlib.py provision-info ./candidate/WatchHIDWatchApp.app
```

重点看：签名是否有效，以及 `provision-info` 给出的过期时间、配置的手表是否在描述文件里。不要运行 `security cms -D` 后把输出贴到聊天或提交到 git：那会打出 UDID 和 `ProvisionedDevices` 列表。只要签名与描述文件仍有效且包含这只手表，就不需要导入原构建机的私钥。

手表已在 `devicectl list devices` 中可见后，优先用脚本安装并拉起应用：

```bash
./scripts/install-signed-watch-app.sh ./candidate/WatchHIDWatchApp.app
# 也可以直接给 zip：
# ./scripts/install-signed-watch-app.sh ./WatchHID-encrypted-hogp.zip
```

`WATCH_UDID` 只放在本机 gitignore 的 `Config/local_devices.env`，不要把个人 UDID 写进文档或打到聊天。免费签名过期、或这只手表不在描述文件里时，应改为第 4 节在本机重新签名，而不是拷贝私钥。

### 开发安装通道不是蓝牙连接

蓝牙菜单里 Apple Watch 已连接（甚至显示 HID BLE），不等于可以把包装上手表。`devicectl` 走的是 CoreDevice 开发通道，常见状态是：

- `connected`：可以安装和拉起应用；
- `available (paired)` 但隧道是断开的：列表里能看到手表，安装往往会在协商隧道时超时；
- `unavailable`：现在装不了。手表仍可能正通过蓝牙连着这台 Mac。

通道不可用时，同时做这些，再重新运行安装脚本：

1. 把手表拿近这台 Mac，点亮并解锁，保持屏幕亮着；
2. 把配对的 iPhone 也拿近并解锁，尽量连同一 Wi-Fi；不必插 USB 线；
3. 等到 `devicectl list devices` 显示这只手表为 `connected`。不要为此重置系统蓝牙，或取消手表的系统配对。

把已签名 zip 从开发机拷到这台电脑时，用普通文件拷贝即可；两台电脑都开着时，也可以用远程桌面或 UU 的传文件。不要拷贝其他电脑的蓝牙偏好设置或钥匙串。重装后，旧的 HID BLE 会话可能会断掉，需要再打开一次 WatchHID。

2026-11-10 11:54（北京时间，Asia/Shanghai）：配对 iPhone 与这台 Mac 同一 Wi-Fi 且已解锁、未插 USB 时，CoreDevice 以 localNetwork 变为 `connected`，已签名加密包安装并 `devicectl launch` 成功。这只是那一次无线装包的观察，不代表以后都必须有 iPhone，也不代表已经验证附近没有 iPhone（无线隔离）时仍能安装。

## 7. 运行 HOGP / 触控板

应用必须在手表**前台**打开，并能看见状态文字。只在锁屏或后台时，主机常常读到的是系统 Apple Watch 的 Device Information，而不是 WatchHID 的 GATT。Mac 作为普通蓝牙 HID 主机接收鼠标即可。此时：

- 不需要 Xcode 正在运行；
- 不需要 iPhone USB 连接到这台 Mac；
- 加密包可以触发主机 `startAutoPairing`。若系统弹出 passkey / 蓝牙配对确认，必须在这台 Mac 的系统对话框里完成确认。这是设置的一步，不是取消手表的系统配对，也不需要重置蓝牙。配对和加密可以成功，系统也可以因此创建 `IOHIDUserDevice`；
- **不能**把「蓝牙设置里显示已连接」（哪怕是 HID BLE）、已经点过配对确认、Xcode / Device Hub 的开发隧道，或系统里一个普通 Mouse / “ZY的Apple Watch” 名称，当成 WatchHID 已成功。成功的实证仍然是：同一 IOHID 节点上出现 Manufacturer=`WatchHID`、ModelNumber=`Ultra2-R1` 以及鼠标/指针 Usage，并且指针真的移动。手表状态若一直停在 `等待 Mac 系统订阅`，也不等于这台 Mac 的订阅已经被应用接受，见下方源码事实。

回来验收的具体手势与听写步骤见 [QUICKSTART.zh-CN.md](QUICKSTART.zh-CN.md)。出门后再开始的最短步骤见 [RETURN-CHECKLIST.zh-CN.md](RETURN-CHECKLIST.zh-CN.md)。

### 新 Mac 不要和已成功的开发机混为一谈

下面把已经看见的事实，和由此作出的推断分开写。不要复制其他电脑的蓝牙密钥、偏好设置或钥匙串。

**已证实：**

- 另一台电脑上已经成功的加密 HOGP 绑定，不能当作可以拷贝过来的密钥来复用。它只属于「这只手表 ↔ 那台电脑的蓝牙控制器」；系统 Apple Watch 配对或 iCloud 都不会把它带来。这是约束，不是“已经在新 Mac 上证明绑定不存在”的证据。
- 在原开发用的 Mac mini 上，系统曾经成功创建 Manufacturer 为 `WatchHID`、ModelNumber 为 `Ultra2-R1` 的鼠标，并且指针可移动。那次验收日志没有出现「因链路未加密而拒绝创建鼠标」的记录。
- 2026-11-10 上午（北京时间，Asia/Shanghai），这台新 Mac 在未加密包下曾读到 WatchHID 的 Device Information 指纹（Manufacturer 先是 `<private>`，随后是 “Apple Inc.”，PnP 为 `BT / 0x004C / 0x0000 / 0x0001`），操作者确认过配对弹窗，随后 BTLEServer 以 `Not creating HID device as the link is not encrypted` 拒绝创建 HID。这只说明那一次创建被“链路未加密”挡住，不能证明这台电脑上完全不存在任何既有绑定。点过配对确认不是 HID 加密已成功。当时没有出现 WatchHID 节点。
- 同日 11:54 已将 mini 签名的加密包（`WH_HOGP_ENCRYPTED` / `standard128-encrypted`）无线安装并拉起。该配方给 Report Map 和输入 Report 设置加密读，并给输入 Report 设置加密通知；不要写成这些读/通知特征还要求加密写。11:54 的无线安装发生在 iPhone 同一 Wi-Fi 且已解锁、未插 USB 时，不能推广成“永远需要 iPhone”或“无线隔离已验证”。
- 同日下午，在 WatchHID 的 GATT 尚未被稳定读到（Manufacturer 常常只有 “Apple Inc.”、没有 PnP；应用一度不在前台）时，主机仍会 `startAutoPairing`，但对端约 60 毫秒内以 Pairing Failed reason=8 中止，没有可见配对界面。协议栈启动了自动配对；对端在确认界面出现之前就中止了。残留或冲突的 LE 绑定只是可能，没有被证明。
- 同日 14:01 起，应用在前台且状态为 `等待 Mac 系统订阅` 时，主机再次读到 WatchHID GATT 指纹（第二条 Manufacturer 为 `<private>`，PnP 为 `BT / 0x004C / 0x0000 / 0x0001`，以及 Report Map / Report）。随后出现 passkey 确认界面，操作者在这台 Mac 上完成确认。14:01:49 加密启用（`isPairing=1`，`smpPairingCompleted status=0`），这台 Mac 订阅了输入 Report，BTLEServer 启动了 `IOHIDUserDevice`。这一窗口内没有 ATT 242、ATT 15、reason=8，也没有 “Not creating HID…”。
- 尽管如此，同一节点上的 WatchHID / `Ultra2-R1` 鼠标身份仍未出现。系统创建的 HID 鼠标身份是 `Apple Inc.` / `Watch7,5` / `ZY的Apple Watch`，报告描述符 52 字节（项目基线 `mouseReportMap` 是 64 字节，长度不一致）。之后在安全桌面上短滑并轻点，指针没有移动，手表仍显示 `等待 Mac 系统订阅`。因此：这台 Mac 上的配对和加密现在有实证；WatchHID 身份和指针移动还没有。不能宣称加密路径已经是快速、可靠的成功方案。不要为此重置刚刚完成的绑定。

当天更完整的时间线和日志摘录见 [new-mac-hogp-2026-11-10.zh-CN.md](new-mac-hogp-2026-11-10.zh-CN.md)。

**源码事实（不是对当天日志的再解释）：**

- `等待 Mac 系统订阅` 表示界面在前台且 `macInputReady` 为假。`macInputReady` 要求探针正在运行、外设管理器已 poweredOn、已持有鼠标 Report，并且当前 CCCD 订阅者集合**精确等于**源码里写死的那一个 Mac 中央标识（来自原先那台 mini；不要写出这个标识）。日常触控发送在调用底层通知前也会再做一次同样的检查。底层通知 API 若被调用，会发给当时所有已订阅的中央；但日常路径在集合不匹配时根本不会调用它。所以这个状态不是“任意 Mac 一订阅就成功”。它也可以解释：这台 Mac 已在 14:01:49 订阅了 Report，手表却仍显示正在等待。
- 默认 PnP 使用 Apple 厂商号 `0x004C`。源码只把它写成可能促使 SameAccount 合并的推测性对照；当天节点以系统 Apple Watch 身份出现，与这条推测相符，但还不是已证实的合并机制。

**推断 / 仍待验证：**

- 默认配方 `standard128` 的 GATT 特征不要求加密，所以新主机可以明文读取报告描述，然后在创建鼠标这一步被拒绝。加密配方的目的，是让新主机在读报告描述时进入配对/加密。这台 Mac 上配对和加密已经完成；要把新 Mac 走到与 mini 相同的可用状态，还需要项目约定的节点身份，以及指针真正移动。
- 指针没有移动的一个有源码依据的主要假说，是输入门和鼠标通知被钉在了另一个 Mac 的中央标识上，因而没有发出报告。不要把它写成唯一原因：身份不是 `WatchHID` / `Ultra2-R1`，以及 52 字节描述符与 64 字节基线不一致，即使报告发出去也可能挡住可用的项目鼠标。
- 成功标准仍然是：同一 IOHID 节点上出现 Manufacturer=`WatchHID`、ModelNumber=`Ultra2-R1` 以及 Generic Desktop 的鼠标/指针 Usage，并且你在安全桌面上看见指针移动。`verify-hogp-mouse.sh` 只检查同节点身份，NODE_OK 不等于指针已经移动。不要为了这一步重置系统蓝牙，或取消手表的系统配对。

## 8. 真实验证与听写边界

- 模拟器可以测界面、系统文本输入回调和取消返回，**不能**证明真实蓝牙 HOGP、系统光标因果关系或语音识别。详见 [SIMULATOR-CHECKS.md](SIMULATOR-CHECKS.md)。
- 听写目前只在手表上预览识别出的文字，不会自动输入 Mac。系统常常先打开键盘页，需要在右下角切到麦克风；不能保证每次都直接进入语音，也不能保证系统一定记住上次选择。
- 英文 HID 键盘向 Mac 打字不是默认功能，默认应保持关闭。

## 9. 常见问题（不要用危险“修复”）

| 现象 | 先怎么理解 | 不要做什么 |
|---|---|---|
| 指针不动，但蓝牙或开发器显示已连接 | 先确认 WatchHID 在手表前台，并能看见状态。若系统弹出 passkey / 配对确认，先在这台 Mac 上完成确认。只完成弹窗、或只看到已连接的 “ZY的Apple Watch” / HID BLE，都不等于项目成功。若状态一直是 `等待 Mac 系统订阅`，源码要求订阅者必须是写死的那一个 Mac 中央标识，这台新 Mac 的订阅不一定会被当成就绪。先保留现场，不要拆掉刚刚完成的绑定。 | 不要取消手表的系统配对、清蓝牙缓存、重置系统蓝牙或关安全防护。 |
| Mac 锁屏 | 锁屏时不要把本机探测失败写成应用损坏。先解锁再测指针。 | 不要为了测试绕过锁屏或改安全设置。 |
| `devicectl` 看不到手表，或列表是 `unavailable` / 只有 `available (paired)` | 开发安装通道和蓝牙不是一回事。先确认完整 Xcode 已选中并完成 first launch、手表已开 Developer Mode、已信任这台电脑；把手表拿近、点亮并解锁；把配对的 iPhone 拿近并解锁，尽量连同一 Wi-Fi（不必插线）。等到状态是 `connected` 再安装。可用 `./scripts/install-signed-watch-app.sh`，通道不可用时它会打印这份清单。 | 不要重置蓝牙或取消系统配对来“打通”开发连接。也不要把蓝牙已连接当成已经可以装包。 |
| 已签名包装不上或运行被拒 | 先看描述文件是否过期、这只手表是否在设备列表中。过期就在本机用开发 Apple ID 重新签名。 | 不要从其他 Mac 复制私钥或登录 token。 |
| 重装后偶发连不上鼠标 | 静态设备信息修复过一类初始化问题，但不是所有前台/启动时序的完整保证。保留现场日志再查。 | 不要把模拟器通过当成真机已恢复。 |

更详细的恢复说明与回归表见 [HOGP-RECOVERY.md](HOGP-RECOVERY.md)。

## 10. 本机签名什么时候是必要步骤

- 只把仍然有效的已签名包装到手表：这台 Mac **不需要**自己的签名证书，也不要从其他电脑拷私钥。
- 要在这台 Mac 上重新构建或改配方（例如下面的加密 HOGP 包）：本机签名就是必要步骤。先在 Xcode > Settings > Accounts 登录开发用 Apple ID，把 team 写入 gitignore 的 `Config/Developer.xcconfig`，安装 `xcodegen`（`brew install xcodegen`），再运行第 11 节的脚本。第一次构建会向该账号申请 Apple Development 证书和描述文件，可能弹出系统或 Xcode 确认；在官方对话框里完成，不要把密码或验证码发到聊天。本机还看不到 Apple Development 证书时，不要以为命令行已经能签。
- 也可以在已经有证书的开发机上签名，把 zip 拷到新 Mac 再安装。新 Mac 仍然必须在**本地**完成 HID 加密绑定。

## 11. 没有可复用的加密 HOGP 绑定时走哪条路径

其他电脑上已经成功的加密 HOGP 绑定**不能**复用到新 Mac。它只存在于「这只手表 ↔ 那台电脑的蓝牙控制器」这一对设备之间；系统 Apple Watch 配对或 iCloud 也不会把这份密钥带过来。不要复制其他电脑的蓝牙偏好设置或钥匙串来“转移”绑定，以免弄乱两边已有的配对。

能复用的是方法，不是密钥。下面这条路径可以较快地重新构建并安装加密配方候选。2026-11-10 它已在这台新 Mac 上完成配对和加密，并创建了 HID 设备，但还没有得到项目约定的 WatchHID 身份，也没有指针移动，因此不能写成快速、可靠的成功方案。在**能签名**的 Mac 上（已有 `Config/Developer.xcconfig` 和 Apple Development 证书）执行：

```bash
./scripts/ship-encrypted-hogp.sh
```

如果这台电脑已经能看到手表：

```bash
./scripts/ship-encrypted-hogp.sh --install
```

脚本会构建并打包配方 `standard128-encrypted`。该配方给 Report Map 和输入 Report 设置加密读，并给输入 Report 设置加密通知；不要说这些读/通知特征还要求加密写。把 zip 拷到要当鼠标主机的那台 Mac 后（安装脚本默认优先用 zip，避免误选陈旧解压目录）：

```bash
./scripts/install-signed-watch-app.sh
```

脚本会在开发通道为 `connected` 时安装并拉起 WatchHID；通道不可用时会说明要先亮起手表、把配对 iPhone 放在同一 Wi-Fi（不必插线），然后退出。装好后：

1. 让 WatchHID 留在手表前台，保持屏幕亮着，确认能看见状态文字。
2. 若系统弹出 passkey / 蓝牙配对确认，在这台 Mac 的对话框里完成确认。不要重置系统蓝牙，也不要取消手表的系统配对。
3. 短滑触控板，再运行：

```bash
./scripts/verify-hogp-mouse.sh
```

`./scripts/verify-hogp-mouse.sh` 通过只表示同一 IOHID 节点上出现了 `WatchHID` / `Ultra2-R1` 和鼠标/指针 Usage，并不表示指针移动已经通过。回来验收还需要你在安全桌面上亲眼看见指针移动。只看到蓝牙菜单里 Apple Watch 已连接（哪怕是 HID BLE）、只点过配对弹窗，或手表仍显示 `等待 Mac 系统订阅`，都还不够。2026-11-10 在这台新 Mac 上，配对和加密已经成功并创建了 HID 设备，但身份是系统 Apple Watch，指针也没有移动；详情见 [new-mac-hogp-2026-11-10.zh-CN.md](new-mac-hogp-2026-11-10.zh-CN.md)。下一步若要改输入门（不再钉在另一个 Mac 的中央标识上）或核对身份/PnP，需要在能签名的电脑上重新出包，而不是重置蓝牙。

给后续接手的人也可以直接看项目 skill：[.cursor/skills/watchhid-new-mac-hogp/SKILL.md](../.cursor/skills/watchhid-new-mac-hogp/SKILL.md)。

## 12. 回滚

原开发机本地目录 `build/diagnostics/recovery-root/` 会保留已签名归档（具体文件名以当时的 `RELEASE-MANIFEST.json` 和 [QUICKSTART.zh-CN.md](QUICKSTART.zh-CN.md) 为准），例如带启用按钮的成功旧版、大触控板基线、以及当前候选。安装回滚包的方式与第 6 节相同：校验签名和描述文件，再 `devicectl` 安装。不要为了回滚去推送仓库或合并主分支。
