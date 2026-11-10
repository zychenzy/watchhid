[English](architecture.md) | **简体中文**

# 架构说明

WatchHID 是仅手表的 Apple Watch 应用。它广播一个蓝牙低功耗 HID-over-GATT（HOGP）鼠标。启用英语输入时，键盘是一个**单独**的 HID 服务。基线鼠标报告保持为 4 字节的相对报告（按键、X、Y、滚轮），没有 Report ID。

主机上不运行 WatchHID 辅助程序。完成绑定并订阅的 Mac，应通过常规 HOGP 协议栈，把这块 Watch 当作系统 HID 鼠标。

watchOS 将 `CBPeripheralManager` 以及常见的外设配置 API 标记为 `API_UNAVAILABLE(watchos)`。本项目通过一个 Objective-C 运行时工厂创建这些对象。这条路径在实际测试过的环境上是可用的。它不是受支持的 Apple API，不是 App Store 审核路径，也不保证未来的 watchOS 版本会继续接受它。

仅在 WatchHID 位于前台且屏幕亮起时发送输入。

## 相关项目（仅作比较）

[darwin-bt-remote](https://github.com/jqssun/darwin-bt-remote) 是一个独立的开源项目，可以把 iPhone、iPad 或 Mac 变成蓝牙 HID 控制器。**本仓库没有复制它的实现或文档。** 该项目使用 AGPL-3.0 许可；下面的说明是我们用自己的话做的架构比较。

| | WatchHID | darwin-bt-remote |
|---|---|---|
| 作为控制器的设备 | Apple Watch 应用 | 按该项目的文档，为 iPhone、iPad 或 Mac |
| 这里使用的无线电 / 配置 | 仅 Bluetooth LE HOGP | 该项目文档写明同时使用 BLE HOGP，并在 macOS 上使用传统蓝牙 HID |
| 外设 API | 官方 watchOS API 不可用；使用运行时工厂 | 按该项目的文档，在 iOS 和 macOS 上使用官方的设备角色 API |
| 主机辅助程序 | 无 | 按该项目的文档，也无 |
| 已验证的内容 | 仅操作者确认过的环境；不是通用操作系统矩阵 | 该项目公布了自己的兼容性说明；这里既不沿用，也不重新测试那些说明 |

共同的思路是：一台 Apple 设备可以向主机呈现标准 HID。对本仓库而言，重要差别在于控制器（Watch 应用）、watchOS 上的 API 缺口，以及更窄、并明确不是矩阵的测试记录。不要把这两套代码视为等价，也不要在它们之间复制源码。
