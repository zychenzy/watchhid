[English](INDEX.md) | **简体中文**

# 文档

当前的用户与操作文档：

- [安装](setup.zh-CN.md) — 签名、构建和安装
- [用法](usage.zh-CN.md) — 触控板、Crown、听写和输出选择
- [故障排除](troubleshooting.zh-CN.md) — 常见失败以及不要做的事
- [模拟器检查](SIMULATOR-CHECKS.zh-CN.md) — 系统文本输入页的官方 UI 测试（不是语音识别或 BLE）
- [架构说明](architecture.zh-CN.md) — WatchHID 的 HOGP 路径，以及与一个相关项目的比较（没有共享代码）

逻辑测试（不使用蓝牙，也不注入系统输入）：

```bash
swiftc Shared/HIDDescriptors.swift Shared/HIDMetadata.swift Shared/KeyboardInputState.swift Shared/MouseInputState.swift \
  scripts/MouseInputStateTests.swift -o /tmp/watchhid-mouse-tests && /tmp/watchhid-mouse-tests
swiftc Shared/OutputHostRouting.swift scripts/OutputHostRoutingTests.swift \
  -o /tmp/watchhid-output-host-tests && /tmp/watchhid-output-host-tests
python3 scripts/test_watchhid_scriptlib.py
```

仓库布局：

```
Apps/Watch/     Watch 应用：HID 外设、触控板、表冠滚动、系统听写
Shared/         HID 描述符与输入状态
Config/         已跟踪的模板；本地签名和设备文件已被 gitignore
scripts/        构建、安装、签名预检、验证和单元测试
docs/           安装、用法、故障排除、模拟器检查、架构说明
project.yml     XcodeGen 源文件
```

仅本地使用（已被 gitignore）：`Config/Developer.xcconfig`、`Config/local_devices.env`，以及整个 `build/` 目录。
