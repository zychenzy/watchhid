---
name: WatchHID new-Mac HOGP
description: 在新 Mac 上安装或启用 WatchHID 系统鼠标，或这台电脑还没有这条手表的加密 HOGP 绑定时使用。不要复制其他电脑的蓝牙绑定，也不要重置系统蓝牙。
---

# 新 Mac / 无加密 HOGP 绑定时的 WatchHID

先读 [docs/SETUP.zh-CN.md](../../../docs/SETUP.zh-CN.md)。成功标准只有一个：系统出现 Manufacturer 为 `WatchHID` 的鼠标，并且触控板短滑时指针会移动。不要把蓝牙菜单里 Apple Watch 已连接、只点过配对确认、或 `devicectl` 开发通道在线当成成功。

## 不要做的事

- 不要把另一台电脑上已经成功的加密 HOGP 绑定拷过来。它只属于「这只手表 ↔ 那台电脑的蓝牙控制器」，系统 Apple Watch 配对或 iCloud 都不会把它带来。
- 不要复制其他电脑的蓝牙偏好设置或钥匙串。
- 不要重置系统蓝牙，也不要取消手表的系统配对。
- 不要打印或提交 UDID、蓝牙地址、描述文件里的设备列表。本机标识只放在 gitignore 的 `Config/local_devices.env`。
- 不要把密码或验证码发到聊天；签名确认只在系统或 Xcode 对话框里完成。

## 什么时候需要本机签名

- 只安装仍然有效的已签名包：这台 Mac 不需要自己的证书，也不要拷私钥。
- 要在这台 Mac 上重新构建或改配方（包括加密 HOGP 包）：本机签名是必要步骤。Xcode > Settings > Accounts 登录项目用的开发 Apple ID，写入 `Config/Developer.xcconfig`，安装 `xcodegen`，第一次构建可能弹出系统或 Xcode 确认。
- 也可以在已经有证书的开发机上签名，把 zip 拷到新 Mac 再安装。新 Mac 仍然必须在本地完成 HID 加密绑定。

## 快速路径

1. 在能签名的 Mac 上运行 `./scripts/ship-encrypted-hogp.sh`，得到 `build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip`。默认配方不要改；这个脚本会带上 `WH_HOGP_ENCRYPTED`。
2. 把 zip 拷到要当鼠标主机的那台 Mac。普通文件拷贝即可；两台电脑都开着时，也可以用远程桌面或 UU 的传文件。不要传蓝牙偏好设置。
3. 开发安装通道和蓝牙 HID 不是一回事。手表可以已经通过蓝牙连着，但 `devicectl` 仍是 `unavailable` 或 `available (paired)` 且隧道断开。此时需要：手表拿近、点亮并解锁、保持屏幕亮着；配对的 iPhone 也拿近并解锁，尽量连同一 Wi-Fi。不必插 USB 线。等到 `devicectl list devices` 显示这只手表为 `connected`。
4. 在主机 Mac 上运行 `./scripts/install-signed-watch-app.sh`（或把 zip / `.app` 路径作为参数）。脚本会校验签名、安装并拉起 WatchHID。如果通道不可用，它会打印上述清单并退出，不要为此重置蓝牙。
5. 让操作者保持手表屏幕亮着。若系统弹出蓝牙配对确认，在对话框里确认。然后短滑触控板，运行 `./scripts/verify-hogp-mouse.sh`。
6. 重装后，旧的 HID BLE 会话可能会断掉。如果暂时看不到新的 HID 初始化，先再打开一次 WatchHID，而不是重置蓝牙。

## 常见误判

- `Not creating HID device as the link is not encrypted`：说明这台 Mac 还没有这条手表的加密 HOGP 绑定。走上面的加密包路径，而不是复用其他电脑的绑定。
- 蓝牙已连接、开发通道 `unavailable`：先按第 3 步恢复 `connected`，再安装。
- 只确认了配对弹窗：还不够，必须以 `verify-hogp-mouse.sh` 和指针移动为准。
