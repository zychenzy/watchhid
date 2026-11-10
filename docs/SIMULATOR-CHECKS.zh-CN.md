[English](SIMULATOR-CHECKS.md) | **简体中文**

# 模拟器检查

这些检查在 watchOS Simulator 中练习系统文本输入页。它们不是语音识别、麦克风、实体触摸或 BLE 测试。

## 覆盖范围

`WatchHIDSimulatorChecks` scheme 会运行 `Tests/WatchHIDUITests/SystemTextEntryTests.swift` 中的官方 XCTest UI 测试：

1. `testTypedSystemCompletionAndReturn` — 打开真正的系统文本输入页，输入一句无害的短句，点系统的 Done 按钮，并断言 Watch 回到触控板，且不显示捕获文本的预览。
2. `testSystemCancelReturnsWithoutPreview` — 点系统的 Cancel 控件，并断言触控板返回且没有预览。

当前的正式行为不会在 Watch 上显示捕获的文本。在实体设备上，当键盘 HID 已打开时，可输入的英语应被发送到 Mac 上当前焦点所在的字段；模拟器检查不会发送 Mac HID 输入，也不能证明这条路径。

模拟器不支持 CoreBluetooth 外设，因此在那里看到等待或未订阅的触控板状态是预期的，并不表示 HID 已被接受。

这些检查使用的仅模拟器启动参数，在实体设备构建中会被编译排除。

## 它们不能声称的内容

- 设备上的语音识别或麦克风行为
- watchOS 会以听写而不是键盘或 Scribble 打开该页面
- BLE HOGP、指针移动或点击
- 实体 Digital Crown 或触控板手势

## 如何运行

使用 `WatchHIDSimulatorChecks` scheme，以及这台 Mac 上已经安装的 watchOS Simulator 目标。不要提交模拟器 UDID。

```bash
xcodegen generate
# Then run the WatchHIDSimulatorChecks scheme from Xcode, or an equivalent
# xcodebuild test against a local watchOS Simulator destination.
```
