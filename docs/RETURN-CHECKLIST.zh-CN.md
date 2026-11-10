# 回来后最短验收清单

加密包已经装上并拉起。2026-11-10（北京时间，Asia/Shanghai）这台新 Mac 已经完成配对和加密，并创建了 HID 设备，但还没有出现项目约定的 WatchHID / `Ultra2-R1` 同节点身份，短滑后指针也没有移动。下面只做最少的本人步骤。不要重置蓝牙，不要取消系统 Apple Watch 配对，不要反复解锁，也不要改 75 秒或其它后台/超时设置。刚完成的绑定不要拆掉。

## 先做这些

1. 解锁这台 Mac，把指针移到安全空桌面。手表拿近、点亮并解锁，保持屏幕亮着。
2. 在手表上手动打开 WatchHID，确认它留在前台，并能看见状态文字。只在锁屏或后台时，主机常常读不到 WatchHID 的 GATT。
3. 看这台 Mac 是否弹出 passkey / 蓝牙配对确认。如果弹出，只在系统对话框里完成确认。加密包可以触发自动配对；配对和加密可以成功，系统也可以因此创建 `IOHIDUserDevice`。
4. 在触控板上短滑一下，再轻点一下。
5. 看指针有没有动，手表状态有没有离开 `等待 Mac 系统订阅`。然后在这台电脑上运行：

```bash
./scripts/verify-hogp-mouse.sh
```

脚本只会检查同一 IOHID 节点是否同时具备 Manufacturer=`WatchHID`、ModelNumber=`Ultra2-R1`、以及 Generic Desktop 鼠标/指针 Usage。`NODE_OK` 不是指针已经移动。只看到已连接的 Apple Watch / HID BLE，或只点过配对确认，都还不够。把脚本结果和你看见的指针情况一起留下即可。

需要时也可以再看一眼系统日志窗口（不要把 UDID 或蓝牙地址贴到聊天）。不要跨两个不同 HID 节点拼接 Manufacturer / Product 来判断成功。

## 失败时

保留证据后再停手：

- `./scripts/verify-hogp-mouse.sh` 的完整输出
- 当时指针有没有动、有没有弹出配对确认、你有没有点确认
- 手表当时的状态文字（例如是否一直是 `等待 Mac 系统订阅`）
- 如需补充现场，把 IOHID / 日志存到本机 `build/diagnostics/`，不要提交，也不要在输出里留下 UDID 或蓝牙地址

然后交给后续排查。不要重置蓝牙，不要取消配对，不要再让人反复解锁或改设置。

## 当前已证实 / 仍待验证

已证实：这台新 Mac 上加密路径可以走完 passkey 确认、启用加密，并由 BTLEServer 创建 HID 设备。当天装在手表上的那一版里，`macInputReady` 和日常鼠标通知还钉在原先那台 mini 的中央标识上（不要写出这个标识），所以当时的 `等待 Mac 系统订阅` 并不表示这台 Mac 的订阅已被应用接受。接受当前订阅者的源码修改已在本分支，但尚未签名安装到手表。

仍待验证：

- 同一节点上是否会出现 `WatchHID` / `Ultra2-R1` 鼠标身份（当天出现的是 `Apple Inc.` / `Watch7,5` / `ZY的Apple Watch`）
- 指针是否会因 WatchHID 而移动（当天短滑后没有移动）
- 这条路径是否快速、可靠
- 附近没有 iPhone 时（无线隔离）开发通道是否仍可安装；11:54 的无 USB 成功安装发生在同一 Wi-Fi 且 iPhone 已解锁时，不能推广成“永远不需要 iPhone”

当前已签名加密包的免费描述文件有效期到 2026-11-15 22:10（北京时间，Asia/Shanghai）。若要在这台电脑上把本分支的修改签出来，按 [SETUP.zh-CN.md](SETUP.zh-CN.md) 第 4 节创建本机 Apple Development 证书，再运行 `./scripts/ship-encrypted-hogp.sh`；不必回到原先的签名机，也不要拷私钥。不要用重置蓝牙代替这次安装验证。安装脚本默认以 zip 为准，避免误选陈旧解压目录。

更完整的证据/推断分界见 [SETUP.zh-CN.md](SETUP.zh-CN.md) 和 [new-mac-hogp-2026-11-10.zh-CN.md](new-mac-hogp-2026-11-10.zh-CN.md)。听写步骤不是这次回来的最低要求，需要时再看 [QUICKSTART.zh-CN.md](QUICKSTART.zh-CN.md)。
