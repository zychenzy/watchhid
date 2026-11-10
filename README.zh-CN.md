[English](README.md) | **简体中文**

# WatchHID

把 Apple Watch 当作 Mac 上的蓝牙低功耗（Bluetooth LE）HID 鼠标使用，并可选用英语听写输入。不需要额外硬件，指针也不需要在 Mac 上安装辅助应用。

Watch 应用界面跟随手表系统语言（英语、简体中文、繁体中文）。本仓库的测试仍为英语。文档提供英语和简体中文。

## 功能

- 仅手表应用：iPhone 上不需要 WatchHID 配套应用（配对的 iPhone 仍是 watchOS 的要求，部分隐私设置可能在手机上）
- 标准的 Bluetooth LE HOGP 鼠标；完成绑定并订阅后，主机会把它当作系统指针
- 可选的英语键盘位于**单独**的 HID 服务上——基线 4 字节鼠标 Report Map 保持不变
- 全屏触控板、Digital Crown 垂直滚动（使用已有的鼠标滚轮字段），以及系统听写（`presentTextInputController`）
- 报告每次只发给一个选定的主机（Device 1、Device 2，……）

## 要求

这些是编译并侧载应用所需要的条件。它们并不是一份已验证设备矩阵。

- 一台装有完整 Xcode 的 Mac（不能只有 Command Line Tools）
- 已打开 Developer Mode 的 Apple Watch
- 与该 Watch 配对的 iPhone
- 能在 Xcode 中为 watchOS 应用签名的 Apple 账户：免费 Personal Team，或付费的 Apple Developer Program 会员资格

不要提交设备 UDID、Team ID、私钥或描述文件。把它们放在从 `Config/` 模板复制出的、已被 gitignore 的文件里。

签名细节，包括**仅适用于免费 Personal Team** 的官方 7 天限制，见 [docs/setup.zh-CN.md](docs/setup.zh-CN.md)。本项目不是 App Store 提交。

## 已验证的环境

以下是操作者确认过的结果，**不是**通用的 Watch、Mac 或 iOS 矩阵。其他 Apple Watch 型号尚未验证；本文没有宣称它们不受支持，也不提供保证。

- **指针和点击**在不止一台 Mac 上可用，并使用当前的单主机 Device 1 / Device 2 路由
- 那次测试使用的硬件是 **Apple Watch Ultra 2**
- **把 iPhone 当作 HID 主机**曾在远离 Mac 时确认过一次；这是个人确认，不是覆盖各 iOS 版本的矩阵
- **向 Mac 进行英语听写**在系统文本输入页接受可输入的英语、且键盘 HID 已打开时可用。Watch 上不会显示捕获的文本。系统可能先打开键盘或 Scribble；没有公开 API 能强制一开始就是听写

当前构建广播的 HID 制造商为 `WatchHID`，型号为 `Ultra2-R1`。这是应用的广播身份字符串，并不要求硬件必须是 Ultra 2。

## 安装

签名、需要你亲自确认的对话框，以及蓝牙权限，请按 [docs/setup.zh-CN.md](docs/setup.zh-CN.md) 操作。如果这台 Mac 上已经有本项目：

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig   # once; fill DEVELOPMENT_TEAM
cp Config/local_devices.env.example Config/local_devices.env     # once; fill this Watch’s UDID
./scripts/check-signing-prereqs.sh
# If the script reports a missing WWDR G3 certificate, see docs/setup.md
./scripts/ship-encrypted-hogp.sh
./scripts/install-signed-watch-app.sh
```

安装脚本只有一个就绪门禁。不要在安装即将开始时立刻运行 `--check-ready`。安装完成后，打开 WatchHID；如果 Mac 出现蓝牙配对提示，请确认；在触控板上短拖一下，然后运行：

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` 只表示同一节点上的 HID 身份匹配。成功是该节点**再加上**你亲眼看到的指针移动。

## 用法

手势、输出选择和听写见 [docs/usage.zh-CN.md](docs/usage.zh-CN.md)。

- 拖动移动指针，轻点左键点击，长按右键点击，用 Crown 滚动（通用 Digital Crown，不是 Ultra Action 按钮）
- 仅在应用位于前台且屏幕亮起时发送输入
- 英语键盘 HID 默认关闭；如果出现 Keyboard Setup Assistant，请将其关闭
- 如果系统页面先打开键盘，请切换到麦克风，然后点 Done

## 限制

- `CBPeripheralManager` 在 watchOS 上是 `API_UNAVAILABLE(watchos)`。本项目在运行时创建该外设。这**不是**受支持的 Apple API，未经 App Store 审核，也不保证未来的 watchOS 版本仍然可用。
- 加密的 HOGP 绑定不能通过系统的 Apple Watch 配对或 iCloud 转移。
- 已通过蓝牙连接的 Watch，并不等于安装时所用的、状态为 `connected` 的 CoreDevice 开发者通道。
- 免费 Personal Team 的描述文件遵循 Apple 文档中的 7 天周期；这里没有把它写成付费会员的规则。
- 不要在已经绑定基线 4 字节鼠标映射的主机上，把键盘和鼠标放进同一份复合 Report Map（这曾经导致指针只能上下移动）。
- 表冠滚动已在当前源码中实现；请在运行此构建的设备上自行确认。
- Watch 的 App Icon 槽位仍为空（watchOS 1024×1024 画板，尚无 PNG）。

## 文档

- [安装](docs/setup.zh-CN.md) — 签名、构建、安装和权限
- [用法](docs/usage.zh-CN.md) — 触控板、Crown、听写、输出设备
- [故障排除](docs/troubleshooting.zh-CN.md)
- [模拟器检查](docs/SIMULATOR-CHECKS.zh-CN.md) — 系统文本输入界面的 UI 测试，不是语音识别或 BLE
- [架构说明](docs/architecture.zh-CN.md) — 本项目的工作方式，以及与一个相关 HOGP 应用的比较（没有共享代码）
- [文档索引](docs/INDEX.zh-CN.md)

逻辑测试（不使用蓝牙，也不注入系统输入）以及仓库布局列在文档索引中。

## 许可

以 [Apache License 2.0](LICENSE) 授权（许可文本为英语）。
