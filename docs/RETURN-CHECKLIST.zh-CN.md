# 回来后最短验收清单

加密包装上并拉起过，但截至 2026-11-10 11:56（北京时间，Asia/Shanghai）这台 Mac 还没有出现 WatchHID 系统鼠标，也还没有新的 HID 服务初始化。下面只做最少的本人步骤。不要重置蓝牙，不要取消系统 Apple Watch 配对，不要反复解锁，也不要改 75 秒或其它后台/超时设置。

## 先做这些

1. 解锁这台 Mac，把指针移到安全空桌面。手表拿近、点亮并解锁，保持屏幕亮着。
2. 在手表上手动打开 WatchHID。
3. 看这台 Mac 是否弹出蓝牙配对确认。如果弹出，只在系统对话框里确认。
4. 在触控板上短滑一下，再轻点一下。
5. 看指针有没有动。然后在这台电脑上运行：

```bash
./scripts/verify-hogp-mouse.sh
```

脚本只会检查同一 IOHID 节点是否同时具备 Manufacturer=`WatchHID`、ModelNumber=`Ultra2-R1`、以及 Generic Desktop 鼠标/指针 Usage。`NODE_OK` 不是指针已经移动。把脚本结果和你看见的指针情况一起留下即可。

需要时也可以再看一眼系统日志窗口（不要把 UDID 或蓝牙地址贴到聊天）。不要跨两个不同 HID 节点拼接 Manufacturer / Product 来判断成功。

## 失败时

保留证据后再停手：

- `./scripts/verify-hogp-mouse.sh` 的完整输出
- 当时指针有没有动、有没有弹出配对确认、你有没有点确认
- 如需补充现场，把 IOHID / 日志存到本机 `build/diagnostics/`，不要提交，也不要在输出里留下 UDID 或蓝牙地址

然后交给后续排查。不要重置蓝牙，不要取消配对，不要再让人反复解锁或改设置。

## 仍待验证

- 加密配方候选（`WH_HOGP_ENCRYPTED` / `standard128-encrypted`）能不能在这台新 Mac 上促成可用的 HOGP 加密绑定
- 这条路径是否快速、可靠，能否解决首次 bond
- 附近没有 iPhone 时（无线隔离）开发通道是否仍可安装；11:54 的无 USB 成功安装发生在同一 Wi-Fi 且 iPhone 已解锁时，不能推广成“永远不需要 iPhone”
- 指针移动本身，以及 WatchHID 节点是否会出现

当前已签名加密包的免费描述文件有效期到 2026-11-15 22:10（北京时间，Asia/Shanghai）。本机没有签名证书；若要重新构建，应在已有证书的开发机上运行 `./scripts/ship-encrypted-hogp.sh`，再把 zip 拷回来安装。安装脚本默认以 zip 为准，避免误选陈旧解压目录。

更完整的证据/推断分界见 [SETUP.zh-CN.md](SETUP.zh-CN.md)。听写步骤不是这次回来的最低要求，需要时再看 [QUICKSTART.zh-CN.md](QUICKSTART.zh-CN.md)。
