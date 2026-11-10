---
name: WatchHID new-Mac HOGP
description: 在新 Mac 上安装或启用 WatchHID 系统鼠标，或这台电脑还没有可复用的加密 HOGP 绑定时使用。不要复制其他电脑的蓝牙绑定，也不要重置系统蓝牙。
---

# 新 Mac / 无加密 HOGP 绑定时的 WatchHID

先读 [docs/SETUP.zh-CN.md](../../../docs/SETUP.zh-CN.md)。回来后的最短步骤见 [docs/RETURN-CHECKLIST.zh-CN.md](../../../docs/RETURN-CHECKLIST.zh-CN.md)。2026-11-10 当天的证据与源码分界见 [docs/new-mac-hogp-2026-11-10.zh-CN.md](../../../docs/new-mac-hogp-2026-11-10.zh-CN.md)。（这些相对链接是从本 skill 文件所在目录出发，向上三级到仓库根目录。）

验收标准有两层，不要混为一谈：

1. `./scripts/verify-hogp-mouse.sh` 报告 `NODE_OK`：同一 IOHID 节点上 Manufacturer 为 `WatchHID`、ModelNumber 为 `Ultra2-R1`，并且有 Generic Desktop 的鼠标/指针 Usage。脚本成功只说明节点身份，不是指针已经移动。
2. 操作者在安全空桌面上短滑/轻点，亲眼看见指针移动。

不要把蓝牙菜单里 Apple Watch 已连接（哪怕是 HID BLE）、只点过配对确认、`devicectl` 开发通道在线，或手表仍显示 `等待 Mac 系统订阅`，当成成功。

## 不要做的事

- 不要把另一台电脑上已经成功的加密 HOGP 绑定拷过来。它只属于「这只手表 ↔ 那台电脑的蓝牙控制器」，系统 Apple Watch 配对或 iCloud 都不会把它带来。不要复制其他电脑的蓝牙偏好设置或钥匙串。
- 不要重置系统蓝牙，也不要取消手表的系统配对。刚刚在这台新 Mac 上完成的配对/加密绑定尤其不要拆掉。
- 不要打印或提交 UDID、蓝牙地址、描述文件里的设备列表，或源码里写死的中央标识。本机标识只放在 gitignore 的 `Config/local_devices.env`。查看描述文件过期和是否包含已配置手表时，用 `python3 scripts/watchhid_scriptlib.py provision-info ./WatchHIDWatchApp.app`，不要把 `security cms -D` 的输出贴出去。
- 不要把密码或验证码发到聊天；签名确认只在系统或 Xcode 对话框里完成。
- 不要在精确 UDID 匹配失败时改去安装另一块 Watch。安装脚本也不会这样做。
- 不要把默认安装源选成一个可能过期的解压目录；有 `WatchHID-encrypted-hogp.zip` 时以 zip 为准。

## 什么时候需要本机签名

- 项目已经拷到这台 Mac、要重新构建或改配方（包括加密 HOGP 包，或把本分支里尚未装到手表的修改签出来）：**默认在本机签名并运行 `./scripts/ship-encrypted-hogp.sh`**。不必再依赖原先的签名机出包，也不要从那台电脑拷私钥。按 [docs/SETUP.zh-CN.md](../../../docs/SETUP.zh-CN.md) 第 4 节：保持 macOS 登录不变，用项目已有的开发 Apple ID（可与系统登录不同）在 **Xcode > Settings > Accounts** 中登录同一 team，打开 **Manage Certificates…**，用 “+” 添加 **Apple Development**。私钥必须留在这台 Mac 的钥匙串。只导入 `.cer`、或钥匙串里只有证书没有配套私钥，都还不能签名；此时不要吊销或删除已有证书，回到 Manage Certificates… 用 “+” 让本机生成私钥。用 `./scripts/check-signing-prereqs.sh` 确认 `security find-identity -v -p codesigning` 已能看到可用身份。不要为了腾名额吊销另一台电脑的证书，除非操作者明确同意。然后写入 gitignore 的 `Config/Developer.xcconfig`（从跟踪的 `Config/Developer.xcconfig.example` 复制），安装 `xcodegen`，再运行 `./scripts/ship-encrypted-hogp.sh`（它会自己调用 `xcodegen generate`）。构建时描述文件可能会刷新，必须仍包含这只手表；不要打印 UDID、`ProvisionedDevices` 或证书序列号。Apple ID / 钥匙串提示要操作者在官方对话框里确认。免费账号约 7 天需手动重签，这是可以接受的。
- 只安装仍然有效的已签名包：这台 Mac 不需要自己的证书，也不要拷私钥。这仍然可行，但不是项目已经在这台电脑上之后的首选重建方式。

## 快速路径

这是可复用的安装与配对步骤。2026-11-10 它已在一台新 Mac 上完成配对和加密并创建了 HID 设备，但还没有得到 `WatchHID` / `Ultra2-R1` 身份，也没有指针移动，因此不能写成已经快速可靠的成功方案。

1. 在这台已有项目拷贝的 Mac 上，按上面「什么时候需要本机签名」或 SETUP 第 4 节准备本机身份，运行 `./scripts/check-signing-prereqs.sh`，再运行 `./scripts/ship-encrypted-hogp.sh`（不要先加 `--install`），得到 `build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip`。默认配方不要改；这个脚本会带上 `WH_HOGP_ENCRYPTED`。该配方给 Report Map 和输入 Report 设置加密读，并给输入 Report 设置加密通知；不要写成这些读/通知特征还要求加密写。若这台电脑就是鼠标主机，不必再把 zip 拷到别处。
2. 只有当签名发生在另一台电脑时，才需要把 zip 拷到要当鼠标主机的那台 Mac。普通文件拷贝即可；不要传蓝牙偏好设置。项目已经在主机上时，应直接在本机出包。
3. 开发安装通道和蓝牙 HID 不是一回事。手表可以已经通过蓝牙连着，但 `devicectl` 仍是 `unavailable` 或 `available (paired)` 且隧道断开。此时需要：手表拿近、点亮并解锁、保持屏幕亮着；配对的 iPhone 也拿近并解锁，尽量连同一 Wi-Fi。不必插 USB 线。等到 `devicectl list devices` 显示这只手表为 `connected`。一次同 Wi-Fi、未插线且 iPhone 已解锁时通道变为 connected 并成功装包，只说明那次可以无线安装，不代表以后都必须有 iPhone，也不代表无线隔离已验证。
4. 在主机 Mac 上运行 `./scripts/install-signed-watch-app.sh`（或把 zip / `.app` 路径作为参数）。无参数时默认优先选用上述 zip，而不是可能陈旧的解压目录。脚本会按精确 UDID 匹配、校验签名、在超时之内安装并拉起 WatchHID；输出会去掉 UDID / 蓝牙地址 / ProvisionedDevices。如果通道不可用，它会打印上述清单并退出，不要为此重置蓝牙。
5. 让操作者把 WatchHID 留在手表前台，保持屏幕亮着，确认能看见状态文字。加密包可以触发主机 `startAutoPairing`。若系统弹出 passkey / 蓝牙配对确认，必须在这台 Mac 的对话框里完成确认。配对和加密可以成功，系统也可以创建 `IOHIDUserDevice`。然后短滑触控板，运行 `./scripts/verify-hogp-mouse.sh`。NODE_OK 之后仍要确认指针真的移动了。
6. 重装后，旧的 HID BLE 会话可能会断掉。如果暂时看不到新的 HID 初始化，先再打开一次 WatchHID，而不是重置蓝牙。应用不在前台时，主机常常只读到系统 Apple Watch 的 Device Information（Manufacturer 只有 “Apple Inc.”，没有项目 PnP），自动配对可能在约 60 毫秒内被对端以 reason=8 中止，因而没有可见弹窗。一旦读到 WatchHID 的 GATT 指纹，passkey 界面是可以出现的。

## 源码门闩与身份

- 2026-11-10 当时装在手表上的加密包里，`等待 Mac 系统订阅` 不是订阅成功：那一版的 `macInputReady` 和日常 `submitMouseReport` 要求 CCCD 订阅者集合精确等于写死的那一个 Mac 中央标识（来自原先那台 mini；不要写出这个标识）。底层通知 API 若被调用会发给所有已订阅中央，但那一版日常路径在集合不匹配时不会调用它。所以新 Mac 即使已经订阅了 Report，状态也可能仍停在等待，触控也不会发出报告。
- 默认 PnP 使用 Apple 厂商号 `0x004C`。源码只把「可能促使 SameAccount 合并」写成推测。2026-11-10 系统创建的鼠标身份是 `Apple Inc.` / `Watch7,5` / `ZY的Apple Watch`，报告描述符 52 字节，与项目基线 `mouseReportMap`（同为 52 字节）一致，因此不能把它当成描述符长度不匹配的证据。身份不符与上述推测相符，但还不是已证实的合并机制。
- 接受当前实际订阅者作为输入主机的源码修改已在本分支（`dc02abf`），但尚未签名安装到手表。配对和加密在这台新 Mac 上已有实证；WatchHID 身份和指针移动仍待验证。不要重置刚刚完成的绑定。要在这台新 Mac 上把该修改签出来，按上面的步骤在本机准备签名身份，再运行 `./scripts/ship-encrypted-hogp.sh`。若装上后身份仍不是 `WatchHID` / `Ultra2-R1`，再单独考虑非 Apple PnP 或如何发布项目自己的 Device Information。

## 常见误判

- `Not creating HID device as the link is not encrypted`：这是当时拒绝创建鼠标的原因，不能单独证明这台电脑上完全没有既有绑定。走上面的加密包路径时，仍然不要复用其他电脑的绑定。
- 蓝牙已连接、开发通道 `unavailable`：先按第 3 步恢复 `connected`，再安装。
- 只确认了配对弹窗、只看到已连接的 HID BLE、或脚本只报了 NODE_OK：都还不够，必须以同节点身份和指针移动一起为准。
- 下午长时间没有配对界面：常常是应用不在前台、WatchHID GATT 没有被读到，对端在界面出现前就用 reason=8 中止了自动配对。不要把它写成“系统根本没有请求配对”。
