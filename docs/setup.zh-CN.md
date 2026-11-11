[English](setup.md) | **简体中文**

# 安装

这是在你自己控制的 Mac 上安装 WatchHID 的公开路径。它不会重置蓝牙绑定，也不会从另一台 Mac 复制加密的 HOGP 绑定。

不要打印或提交设备 UDID、蓝牙地址、描述文件中的设备列表、证书序列号或 Apple ID 邮箱。本地标识只应放在从下面模板复制出的、已被 gitignore 的文件里。

## 1. 前提条件

- 完整的 Xcode，不能只有 Command Line Tools
- 已在 Apple Watch 上打开 Developer Mode。操作者测试是在 Apple Watch Ultra 2 上进行的。其他型号不是一份已验证矩阵，本文也没有宣称它们不受支持。
- 与该 Watch 配对的 iPhone（这是 watchOS 的要求；WatchHID 本身是仅手表应用，没有配套的 iPhone 应用）
- 能在 Xcode 中为 watchOS 应用签名的 Apple 账户：免费 Personal Team，或付费的 Apple Developer Program 会员资格。本项目是在免费 Personal Team 上测试的；这是一个实例，不是必须使用同类账户。Apple 文档写明，免费 Personal Team 的 App ID、设备和描述文件会在签发后 7 天过期，过期后需要重新构建并安装：[About your developer account](https://developer.apple.com/help/account/basics/about-your-developer-account/)。不要把这个 7 天周期当成付费会员的规则。本项目不是 App Store 提交。

用于登录 macOS 的账户，和用于签名的 Apple ID，可以不是同一个。不要只为了签名去改 Mac 登录账户。

## 2. 本地配置

在仓库根目录执行：

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig
cp Config/local_devices.env.example Config/local_devices.env
```

在 xcconfig 中填写 `DEVELOPMENT_TEAM`，在 env 文件中填写 `WATCH_UDID`。这两个文件已被 gitignore。

## 3. 签名预检

```bash
./scripts/check-signing-prereqs.sh
```

如果脚本报告缺少 WWDR G3 中间证书：

```bash
./scripts/check-signing-prereqs.sh --install-wwdr
```

如果 macOS 弹出登录钥匙串提示，请确认。这会安装 Apple 的官方中间证书，并不会新建 Development 证书。

只有在预检指出这台 Mac 上没有签名身份时，才使用 Xcode 的 **Manage Certificates… > +**。如果 **+** 表示当前已经有 Development 证书，请停下来先修复信任。不要吊销另一台 Mac 仍在使用的证书。

## 4. 构建已签名的 Watch 应用

```bash
./scripts/ship-encrypted-hogp.sh
```

这会在 `build/diagnostics/recovery-root/` 下生成一份已签名的 zip。它不会安装应用。

如有 codesign 钥匙串提示，请亲自确认。

## 5. 安装

开发者通道并不等于已通过蓝牙连接的 Apple Watch。`devicectl list devices` 里出现 `connected` 条目，本身并不足够。

准备好安装时，**只**运行：

```bash
./scripts/install-signed-watch-app.sh
```

可以把已签名 zip 的路径作为参数传入。脚本会在列表状态为 `connected` 之后，继续探测 CoreDevice 细节和 DDI 服务。这就是唯一的就绪门禁。

**不要**在即将安装时立刻运行 `./scripts/install-signed-watch-app.sh --check-ready`。`--check-ready` 是单独的诊断探测，用于你并不在安装的时候。

让 Watch 保持靠近、唤醒、解锁且屏幕亮起。附近一台已解锁、并与 Mac 在同一网络上的 iPhone 有助于开发者通道；这并不意味着需要配套应用。

如果安装失败并出现 “Failed to allocate RSD device”、CoreDevice 4000 或 RemotePairing 1001，请稍等，确认 Watch 仍解锁且屏幕亮起，然后把同一个安装脚本再运行一次。不要循环重试，不要重置蓝牙，也不要更换证书。

## 6. 首次使用

在 Watch 上打开 WatchHID。

“仅手表应用”意味着 WatchHID 不需要配套的 iPhone 应用。配对的 iPhone 仍是 watchOS 的要求，部分系统隐私设置可能仍在那台 iPhone 上管理。Apple 文档写明，部分 Apple Watch 隐私设置会与 iPhone 共享，并在 iPhone 的 **设置** 应用中的 **隐私与安全性** 里更改（其中的例子包括定位服务、分析、通讯录和健康）：[View app settings and storage on Apple Watch](https://support.apple.com/guide/watch/view-app-settings-and-storage-apd31a7d203c/watchos)。Apple 关于蓝牙隐私的文章（其中包含 Apple Watch）写明，你可以在 **设置 > 隐私与安全性 > 蓝牙**（Settings > Privacy & Security > Bluetooth）中允许或撤销应用的蓝牙访问：[If an app would like to use Bluetooth on your device](https://support.apple.com/en-us/102267)。

如果 Watch 一直无法进入可广播的就绪状态——例如一直在等待主机，或者 Watch 的 **设置 > 隐私与安全性 > 蓝牙** 控件不可用，并提示部分隐私设置与 iPhone 共享——请使用已配对 iPhone 上的 **设置** 应用（这并不是说 iPhone 上的 **Watch** 应用一定能改到同一个控件）：

1. 在已配对的 iPhone 上，打开 **设置 > 隐私与安全性 > 蓝牙**。
2. 如果列表里有 WatchHID，请打开它。
3. 回到 Watch 上的 WatchHID。不要重置或取消配对系统蓝牙，也不要为了改这项权限而重装应用。

在 Watch 的蓝牙控件不可用、并显示上述共享设置提示时，这条 iPhone 设置路径已确认能恢复 WatchHID。这是一次已确认的情况，不是每一种 watchOS 设置的必须步骤。如果 iPhone 的蓝牙隐私列表里没有 WatchHID，请查看当前 Watch 和 iPhone 的隐私状态，而不要随意重置蓝牙或重装。

若要把 iPhone 当作鼠标/指针主机使用，请在那台目标 iPhone（要显示指针的那一台）上打开 **设置 > 辅助功能 > 触控 > 辅助触控**。这是系统设置，不是 WatchHID 配套应用；WatchHID 仍然是仅手表应用。配对的 iPhone 仍是 watchOS 的要求，但那与这一步不是同一件事。

这与上面在已配对 iPhone 上进行的 **设置 > 隐私与安全性 > 蓝牙** 步骤不是同一件事。那些步骤只涉及在配对 iPhone 上管理 Watch 隐私控件时，WatchHID 的蓝牙权限。接收指针的 iPhone 可以是那台已配对的手机，也可以是另一台 iPhone。

如果 macOS 显示蓝牙配对提示，请在系统对话框中确认。在触控板上短拖一下，然后运行：

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` 表示这台 Mac 看到一个带有该应用广播 HID 身份（当前为 `WatchHID` / `Ultra2-R1`）且用途为鼠标/指针的 IOHID 节点。这些字符串来自当前构建，不是实体 Watch 的型号名称。它不能证明指针已经移动。成功是该节点再加上你亲眼看到的移动。如果在本地构建中改了这些广播字符串，请用 `WATCHHID_HID_MANUFACTURER` 和 `WATCHHID_HID_MODEL` 指向验证脚本。

一台新的 Mac 需要自己的加密 HOGP 绑定。系统的 Apple Watch 配对和 iCloud 不会从另一台 Mac 复制该绑定。

## 需要你亲自确认的对话框

| 情况 | 你应该做的 |
|---|---|
| 钥匙串或 codesign 提示 | 在官方对话框中确认。不要把密码粘贴到聊天里。 |
| 安装 WWDR G3 | 在 `--install-wwdr` 之后确认钥匙串提示。 |
| 蓝牙配对 / 通行密钥 | 在 WatchHID 位于前台时，在 macOS 系统对话框中确认。 |
| Keyboard Setup Assistant | 把它关闭。WatchHID 不需要完成识别。不要用另一把键盘来识别它。 |
