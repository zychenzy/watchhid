[English](troubleshooting.md) | **简体中文**

# 故障排除

请先对照相应的行。不要为了“修好” WatchHID 而重置系统蓝牙，或取消配对系统的 Apple Watch。

| 现象 | 可能含义 | 该怎么做 |
|---|---|---|
| Watch 一直无法进入可广播的就绪状态，或 Watch 上的蓝牙权限控件不可用，并提示设置与 iPhone 共享 | 即使 WatchHID 没有配套的 iPhone 应用，部分 Watch 隐私设置仍可能在已配对的 iPhone 上管理 | 在已配对的 iPhone 上打开 **设置** 应用，进入 **设置 > 隐私与安全性 > 蓝牙**（Settings > Privacy & Security > Bluetooth）。如果列表里有 WatchHID，请打开它，然后回到 WatchHID。不要重置或取消配对系统蓝牙，也不要为此重装应用。如果列表里没有 WatchHID，请查看当前的隐私状态，而不是去重置。Apple 文档说明了 Watch/iPhone 共享的隐私管理，以及“设置 > 隐私与安全性 > 蓝牙”这条路径；在 Watch 控件不可用时，这条 iPhone 设置恢复路径已得到确认，但它不是每种环境的普遍要求。 |
| 指针不移动，但 Watch 显示 Ready | Ready 只表示所选主机已经订阅 | 在设置里选中目标 Device，点 Test 或拖动，并观察那台机器。如果 macOS 出现配对提示，请确认。然后运行 `./scripts/verify-hogp-mouse.sh`，再加上你亲眼看到的移动。 |
| `verify-hogp-mouse.sh` 报告 `NODE_OK`，但仍然看不到移动 | 身份匹配并不是移动测试 | 拖动时盯着桌面。当前选中的输出可能是另一台主机。 |
| 打开键盘后，指针只能上下移动 | 在已经绑定基线 4 字节鼠标映射的主机上，使用了复合的鼠标+键盘 Report Map | 关闭英语键盘 HID，恢复基线鼠标映射。不要在该绑定上使用复合 Report Map。当前应用把键盘放在单独的服务上。 |
| 出现 Keyboard Setup Assistant | macOS 看到了一个新的键盘 HID | 关闭该助理。不要完成识别，也不要用另一把键盘来识别 WatchHID。没有官方方法能保证它一定不出现。 |
| 系统输入页打开的是键盘或 Scribble，而不是录音 | 系统选择了初始输入方式 | 在该系统页面中切换到麦克风，然后听写并点 Done。这是预期行为；公开 API 并不能强制一开始就是听写。 |
| 听写结束了，但 Mac 上什么也没打出来 | 可能键盘 HID 是关闭的、Mac 上的字段没有焦点，或者结果为空、被取消、或不是 ASCII | 打开英语键盘 HID，把焦点放在可输入字段上，并用系统的 Done 控件接受可输入的英语。空的或被取消的输入页不会打字。 |
| 安装失败，出现 “Failed to allocate RSD device”，或 CoreDevice / RemotePairing 通道超时 | 列表里的 `connected` 条目并不是足够的安装门禁 | 让 Watch 保持靠近、唤醒、解锁且屏幕亮起。只运行 `./scripts/install-signed-watch-app.sh`（它自己会做就绪探测）。可选的单独诊断：在你**并不**即将安装时，运行 `./scripts/install-signed-watch-app.sh --check-ready`。不要把 `--check-ready` 和安装紧挨着连续跑。不要在很短的间隔里反复重试。不要吊销证书。 |
| 安装找不到这块 Watch | 脚本只匹配 `Config/local_devices.env` 里的 `WATCH_UDID` | 确认你已经为这块 Watch 填好了那个被 gitignore 的 env 文件。不要从列表里猜测另一台设备。 |
| 一台新的 Mac 始终得不到鼠标节点 | 加密的 HOGP 绑定不能转移 | 在这台 Mac 上建立新的绑定。不要从另一台 Mac 复制蓝牙偏好设置或钥匙串项目。 |
| Watch 休眠或回到表盘后，输入停止 | 应用必须位于前台且屏幕亮起 | 重新打开 WatchHID，并开始一个新的手势。不支持后台输入。 |
| 卸载 iPhone 上的 WatchHID 应用后，Watch 应用消失了 | 较旧的 iOS 产品仍可能把同一个 Watch 包作为配套应用嵌入。删除那个 iPhone 应用时，可能会把 Watch 应用一起带走。当前的仅手表包不需要配套的 iPhone 应用。 | 直接安装当前的仅手表 Watch 应用。它被标记为仅手表，没有配套应用的 bundle identifier，并且已确认可以在未安装 iPhone WatchHID 应用的情况下运行。不要把残留的、内嵌 Watch 应用的旧 iOS 产品当成当前的打包方式。 |

## 命令

```bash
./scripts/check-signing-prereqs.sh
./scripts/install-signed-watch-app.sh
./scripts/verify-hogp-mouse.sh
```

`--check-ready` 只用于不做安装的探测：

```bash
./scripts/install-signed-watch-app.sh --check-ready
```
