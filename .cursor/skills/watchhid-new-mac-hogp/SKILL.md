---
name: WatchHID new-Mac HOGP
description: 在新 Mac 上安装或启用 WatchHID 系统鼠标，或这台电脑还没有可复用的加密 HOGP 绑定时使用。不要复制其他电脑的蓝牙绑定，也不要重置系统蓝牙。
---

# 新 Mac / 无加密 HOGP 绑定时的 WatchHID

先读 [docs/SETUP.zh-CN.md](../../../docs/SETUP.zh-CN.md)。回来后的最短步骤见 [docs/RETURN-CHECKLIST.zh-CN.md](../../../docs/RETURN-CHECKLIST.zh-CN.md)。（这两个相对链接是从本 skill 文件所在目录出发，向上三级到仓库根目录。）

验收标准有两层，不要混为一谈：

1. `./scripts/verify-hogp-mouse.sh` 报告 `NODE_OK`：同一 IOHID 节点上 Manufacturer 为 `WatchHID`、ModelNumber 为 `Ultra2-R1`，并且有 Generic Desktop 的鼠标/指针 Usage。脚本成功只说明节点身份，不是指针已经移动。
2. 操作者在安全空桌面上短滑/轻点，亲眼看见指针移动。

不要把蓝牙菜单里 Apple Watch 已连接、只点过配对确认、或 `devicectl` 开发通道在线当成成功。

## 不要做的事

- 不要把另一台电脑上已经成功的加密 HOGP 绑定拷过来。它只属于「这只手表 ↔ 那台电脑的蓝牙控制器」，系统 Apple Watch 配对或 iCloud 都不会把它带来。不要复制其他电脑的蓝牙偏好设置或钥匙串。
- 不要重置系统蓝牙，也不要取消手表的系统配对。
- 不要打印或提交 UDID、蓝牙地址、描述文件里的设备列表。本机标识只放在 gitignore 的 `Config/local_devices.env`。查看描述文件过期和是否包含已配置手表时，用 `python3 scripts/watchhid_scriptlib.py provision-info ./WatchHIDWatchApp.app`，不要把 `security cms -D` 的输出贴出去。
- 不要把密码或验证码发到聊天；签名确认只在系统或 Xcode 对话框里完成。
- 不要在精确 UDID 匹配失败时改去安装另一块 Watch。安装脚本也不会这样做。
- 不要把默认安装源选成一个可能过期的解压目录；有 `WatchHID-encrypted-hogp.zip` 时以 zip 为准。

## 什么时候需要本机签名

- 只安装仍然有效的已签名包：这台 Mac 不需要自己的证书，也不要拷私钥。
- 要在这台 Mac 上重新构建或改配方（包括加密 HOGP 包）：本机签名是必要步骤。Xcode > Settings > Accounts 登录项目用的开发 Apple ID，写入 `Config/Developer.xcconfig`，安装 `xcodegen`，第一次构建可能弹出系统或 Xcode 确认。
- 也可以在已经有证书的开发机上签名，把 zip 拷到新 Mac 再安装。新 Mac 仍然必须在本地完成 HID 侧的绑定过程（如果需要的话）。这不是“把 mini 的密钥复制过来”。

## 快速路径（构建候选，不是已证明的首次绑定方案）

1. 在能签名的 Mac 上运行 `./scripts/ship-encrypted-hogp.sh`，得到 `build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip`。默认配方不要改；这个脚本会带上 `WH_HOGP_ENCRYPTED`。该配方给 Report Map 和输入 Report 设置加密读，并给输入 Report 设置加密通知；不要写成这些读/通知特征还要求加密写。
2. 把 zip 拷到要当鼠标主机的那台 Mac。普通文件拷贝即可；两台电脑都开着时，也可以用远程桌面或 UU 的传文件。不要传蓝牙偏好设置。
3. 开发安装通道和蓝牙 HID 不是一回事。手表可以已经通过蓝牙连着，但 `devicectl` 仍是 `unavailable` 或 `available (paired)` 且隧道断开。此时需要：手表拿近、点亮并解锁、保持屏幕亮着；配对的 iPhone 也拿近并解锁，尽量连同一 Wi-Fi。不必插 USB 线。等到 `devicectl list devices` 显示这只手表为 `connected`。一次同 Wi-Fi、未插线且 iPhone 已解锁时通道变为 connected 并成功装包，只说明那次可以无线安装，不代表以后都必须有 iPhone，也不代表无线隔离已验证。
4. 在主机 Mac 上运行 `./scripts/install-signed-watch-app.sh`（或把 zip / `.app` 路径作为参数）。无参数时默认优先选用上述 zip，而不是可能陈旧的解压目录。脚本会按精确 UDID 匹配、校验签名、在超时之内安装并拉起 WatchHID；输出会去掉 UDID / 蓝牙地址 / ProvisionedDevices。如果通道不可用，它会打印上述清单并退出，不要为此重置蓝牙。
5. 让操作者保持手表屏幕亮着。若系统弹出蓝牙配对确认，在对话框里确认。然后短滑触控板，运行 `./scripts/verify-hogp-mouse.sh`。NODE_OK 之后仍要确认指针真的移动了。
6. 重装后，旧的 HID BLE 会话可能会断掉。如果暂时看不到新的 HID 初始化，先再打开一次 WatchHID，而不是重置蓝牙。

加密包路径截至 2026-11-10 11:56（北京时间，Asia/Shanghai）仍未在这台新 Mac 上出现 WatchHID 节点，也未观察到新的 HID 服务初始化。不要宣称它已经解决首次 bond，或已经是快速可靠的成功路径。

## 常见误判

- `Not creating HID device as the link is not encrypted`：这是当时拒绝创建鼠标的原因，不能单独证明这台电脑上完全没有既有绑定。走上面的加密包候选路径时，仍然不要复用其他电脑的绑定。
- 蓝牙已连接、开发通道 `unavailable`：先按第 3 步恢复 `connected`，再安装。
- 只确认了配对弹窗，或脚本只报了 NODE_OK：都还不够，必须以同节点身份和指针移动一起为准。
