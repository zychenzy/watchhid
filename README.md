# WatchHID

只用 Apple Watch + iPhone，把手表做成蓝牙 HID 鼠标（立项 R1 探针阶段）。

- 手表：Apple Watch Ultra 2 · watchOS 27.2 (24S118)
- 手机：iPhone 16 Pro Max · iOS 27.0.1
- 签名：可使用免费 Personal Team 或付费会员（免费账号需要定期续签）
- Bundle ID：`com.zy.watchhid` / `com.zy.watchhid.watchkitapp`

## 工程结构

```
Apps/iOS/          iPhone 宿主：BLE 扫描、手表日志、测试清单
Apps/Watch/        watchOS R1 探针：动态 CBPeripheralManager、HID GATT、R2 枚举
Shared/            HID 描述符与日志模型
scripts/           build.sh / run_watch.sh / scan_mac.swift
docs/              补充笔记
project.yml        XcodeGen 源
```

相关参考（R2 后续）：[REA](https://github.com/morluto/rea)（蓝牙/BLE 逆向与捕获重建能力，方向是分析抓包，不是手表广播本身）。

## 本地编译（无需签名）

```bash
./scripts/build.sh
```

会生成 `WatchHID.xcodeproj`，并对 iOS Simulator / watchOS Simulator 的 generic destination 做 `CODE_SIGNING_ALLOWED=NO` 编译。

## 晚上真机测试清单

### 前置

1. Ultra 2 已与 iPhone 配对；the development Mac 的 Xcode 能选中 iPhone，手表作为 paired watch destination 可见。
2. 打开 `WatchHID.xcodeproj`，两个 target 的 Signing Team 选择你的 Xcode 签名队（或 Automatic）。
3. 首次运行允许蓝牙权限（手表 + 手机）。

### 步骤

| 步 | 在哪 | 点什么 | 看什么 |
|---|---|---|---|
| 1 | iPhone · WatchHID ·「扫描」 | 开始扫描 | 中央状态 poweredOn；列表先可为空 |
| 2 | 手表 · WatchHID | 开始广播 | 日志出现 R2 枚举；随后 Attempt B 动态创建；state 一行 |
| 3 | 手表日志 | 读 state / addService / advertise | `unsupported`、`UUID is not allowed`、或 `Advertising: Watch Mouse` |
| 4 | iPhone 扫描列表 | 等 5–15s | 是否出现 **Watch Mouse**，Appearance `0x03C2`，Service `1812` |
| 5 | （可选）nRF Connect | 扫描 | 交叉确认广告包 |
| 6 | （可选）Mac | `./scripts/run_mac_scan.sh` | 终端打印 FOUND Watch Mouse |
| 7 | 手表 | 导出日志到 iPhone | iPhone「手表日志」页出现完整文本 |
| 8 | 记录 | 截图 + 日志 | 回写立项 Page：R1 通过 / 不通过 |

### 判定

- **R1 通过**：任一扫描端稳定看到名为 Watch Mouse 的 BLE 广告（哪怕 HID 服务稍后被拒）。
- **R1 不通过但实验成功**：`state=unsupported`，或 `addService(0x1812)` / `startAdvertising` 给出明确错误。把错误原文记入 Page，进入 R2。
- **环境失败**：权限弹窗拒绝、手表 App 未装上、WCSession 未激活——先修环境，不记为 R1 技术结论。

## 部署提示

```bash
./scripts/run_watch.sh   # 打印设备与命令提示
```

免费账号无法使用稳定的自动 `devicectl` 长驻能力时，优先用 Xcode Run。

## 明确不做

外接芯片 / Mudra / 改控 Mac / XCUITest 路线。本仓库只服务 Watch → iPhone HID 广播主线。
