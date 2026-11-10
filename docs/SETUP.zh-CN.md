# WatchHID：新 Mac 开发环境 Setup

本文说明如何在一台新 Mac 上安装官方 Xcode、配置签名，以及安装或构建 WatchHID。步骤按官方要求与已核实现象编写；未完成的步骤不会写成已经成功。

主仓库默认留在现有开发机，不必为了安装已签名包而把整个项目再 clone 一份。本地设备标识与 team ID 只放在 gitignore 的 `Config/Developer.xcconfig`、`Config/local_devices.env`，不要写进文档或提交到 git。

## 1. 先分清两件事

- **安装已有签名包**：把已经签好的 watchOS `.app` 装到手表。只要描述文件仍有效，且目标手表 UDID 已在该描述文件中，就不需要从另一台 Mac 拷贝私钥或登录 token。仍需要本机有完整 Xcode/`devicectl`，并且能看到这块手表。
- **在本机重新构建/签名**：用本机 Xcode 登录的 Apple 开发账号签发新的证书和描述文件。不要从其他电脑复制钥匙串私钥。

另外：**这台 Mac 的系统登录 / iCloud 账号，可以和 Xcode 里用于签名的 Apple ID 不是同一个。** 不要为了开发签名去退出或更换 macOS / iCloud 账号。在 Xcode > Settings > Accounts 中额外添加开发用的免费 Apple ID 即可。

运行已经装在手表上的 WatchHID、让它给 Mac 当蓝牙鼠标时，**不需要** Xcode 保持打开，也**不需要** iPhone 通过 USB 接到这台 Mac。

## 2. 官方版本兼容

先看本机系统：

```bash
sw_vers
```

再对照 Apple 官方表格：[SDK and system requirements](https://developer.apple.com/xcode/system-requirements/)。不要按旧印象安装不支持当前 macOS 的 Xcode。

已核实的对应关系（以官方表为准，日期会变）：

| 本机 macOS | 可用的正式版 Xcode | 不要用 |
|---|---|---|
| macOS 27.2 | **Xcode 27.2**（含 watchOS 27.2 / iOS 27.2 / macOS 27.2 SDK）。Xcode 27 / 27.1 也声明支持 macOS 26.6 及更新版本，但应优先与当前系统/SDK 对齐的正式版。 | **Xcode 26.6**：官方只支持 macOS 26.2–26.x，不能装在 macOS 27.2 上。也不要为了本项目去装 Xcode 27.3 beta，除非你明确需要更新的 SDK。 |

设备支持方面，Xcode 27.2 可在 watchOS 10 及更新的真机上安装和调试。下载前确认磁盘空间：App Store 列出的 Xcode 27.2 约 3.1 GB，解压/安装后占用更大，若还要下载 watchOS 模拟器运行时需要再留几 GB。空间紧张时，不要同时开始很大的 macOS 系统更新。

## 3. 安装完整 Xcode

只使用官方来源：

1. **Mac App Store** 中的 Xcode（当前正式版如为 27.2，即可直接装）。可用这台 Mac 现有的 App Store 登录，不必换成开发签名账号，也不必改 iCloud。
2. [Apple Developer 下载](https://developer.apple.com/download/all/?q=Xcode) 中的 `Xcode_27.2.xip`，或用已安装的 `xcodes` 指定版本（例如 `xcodes install 27.2`）。这条路径会要求在官方界面登录 Apple ID；把密码和验证码只打在系统/Apple 自己的输入框里，不要发到聊天或日志。

本机若只有 Command Line Tools，`xcrun devicectl` 可能只是占位提示「请安装 Xcode」，不能列设备或装包。装好完整 Xcode.app 之后再执行：

```bash
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -runFirstLaunch
xcodebuild -version
xcrun devicectl --version
xcrun devicectl list devices
```

`sudo` 和首次许可会弹出系统自己的管理员密码/许可窗口，在本机对话框中确认即可。`xcode-select` 与 first launch 完成前，不要指望 CoreDevice 已经可用。

## 4. 免费账号签名（本机构建时）

若只需安装仍然有效的已签名包，可先跳过本节，见第 6 节。

若要在这台 Mac 上重新 build / sign：

1. 保持当前 macOS / iCloud 登录不变。
2. 打开 Xcode > Settings > Accounts，添加**此前用于本项目的免费 Apple ID（个人 team）**。按系统提示完成登录和双重验证；不要在聊天里发送密码或验证码。
3. 把 `Config/Developer.xcconfig.example` 复制为 gitignore 的 `Config/Developer.xcconfig`，填入该账号在 Xcode 中显示的 `DEVELOPMENT_TEAM`。不要提交这个文件，也不要从别的电脑拷钥匙串私钥。
4. 免费个人 team 的开发描述文件有效期通常约 7 天，过期后需要在本机用同一账号重新签发，而不是迁移旧私钥。

然后按仓库根目录 README 的 signed Watch device build 流程：`xcodegen generate`，再 `xcodebuild` / Xcode Run。`devicectl` 激活不稳定时，优先用 Xcode 直接 Run 到手表。

## 5. 手表 Developer Mode 与开发配对

要在这台新 Mac 上安装或调试 Watch 应用，通常需要：

1. 在 Apple Watch 的「设置 > 隐私与安全性」中打开 **Developer Mode**，按系统要求重启。
2. 手表解锁并靠近这台 Mac。第一次开发配对时，附近的配对 iPhone 可能有帮助，但这不等于以后运行鼠标功能必须插着手机 USB。
3. 手表或 iPhone 上如果出现「信任这台电脑」，在设备上确认。
4. 用 `xcrun devicectl list devices` 确认能看到这块 Watch，且开发者模式为可用状态。

**不要**为了让设备出现或为了修鼠标而去取消配对、重置系统蓝牙或关闭安全防护。

## 6. 安装已有签名包

已签名归档是 watchOS `.app` 的 zip，不是可双击的 Mac 应用。典型位置在原开发机的本地目录 `build/diagnostics/recovery-root/`（该目录已 gitignore，不会随仓库推送）。

安装前在本机检查，不要把描述文件或 UDID 写回 git：

```bash
# zip 里可能带有 AppleDouble 的 ._* 文件，先去掉再校验
ditto -x -k WatchHID-return-home-candidate.zip ./candidate
find ./candidate -name '._*' -delete
codesign --verify --verbose=2 ./candidate/WatchHIDWatchApp.app
security cms -D -i ./candidate/WatchHIDWatchApp.app/embedded.mobileprovision
```

重点看：签名是否有效、证书是否仍是 Apple Development、描述文件是否过期、`ProvisionedDevices` 是否包含**这块**手表。只要这些成立，就不需要导入原构建机的私钥。

手表已在 `devicectl list devices` 中可见后：

```bash
xcrun devicectl device install app --device "$WATCH_UDID"   ./candidate/WatchHIDWatchApp.app
```

`WATCH_UDID` 使用本机 gitignore 配置或 `devicectl` 当时列出的标识，不要把个人 UDID 写进文档。免费签名过期、或这只手表不在描述文件里时，应改为第 4 节在本机重新签名，而不是拷贝私钥。

## 7. 运行 HOGP / 触控板

应用装上手表并在手表前台打开后，Mac 作为普通蓝牙 HID 主机接收鼠标即可。此时：

- 不需要 Xcode 正在运行；
- 不需要 iPhone USB 连接到这台 Mac；
- **不能**把「蓝牙设置里显示已连接」、Xcode / Device Hub 的开发隧道，或系统里一个普通 Mouse 名称，当成 WatchHID 已成功。成功的实证是系统 HID 出现项目约定的身份（例如 Manufacturer 为 `WatchHID`）并且指针真的移动。

回来验收的具体手势与听写步骤见 [QUICKSTART.zh-CN.md](QUICKSTART.zh-CN.md)。

## 8. 真实验证与听写边界

- 模拟器可以测界面、系统文本输入回调和取消返回，**不能**证明真实蓝牙 HOGP、系统光标因果关系或语音识别。详见 [SIMULATOR-CHECKS.md](SIMULATOR-CHECKS.md)。
- 听写目前只在手表上预览识别出的文字，不会自动输入 Mac。系统常常先打开键盘页，需要在右下角切到麦克风；不能保证每次都直接进入语音，也不能保证系统一定记住上次选择。
- 英文 HID 键盘向 Mac 打字不是默认功能，默认应保持关闭。

## 9. 常见问题（不要用危险“修复”）

| 现象 | 先怎么理解 | 不要做什么 |
|---|---|---|
| 指针不动，但蓝牙或开发器显示已连接 | 可能是初始化时 ATT242 等错误，Mac 没有创建可用的系统鼠标节点。先退出并在手表上手动重新打开应用，再短滑。 | 不要取消配对、清蓝牙缓存、重置系统蓝牙或关安全防护。 |
| Mac 锁屏 | 锁屏时不要把本机探测失败写成应用损坏。先解锁再测指针。 | 不要为了测试绕过锁屏或改安全设置。 |
| `devicectl` 看不到手表 | 先确认完整 Xcode 已选中并完成 first launch、手表已开 Developer Mode、已信任这台电脑，且手表在附近并已唤醒。 | 同样不要重置蓝牙或取消系统配对来“打通”开发连接。 |
| 已签名包装不上或运行被拒 | 先看描述文件是否过期、这只手表是否在设备列表中。过期就在本机用开发 Apple ID 重新签名。 | 不要从其他 Mac 复制私钥或登录 token。 |
| 重装后偶发连不上鼠标 | 静态设备信息修复过一类初始化问题，但不是所有前台/启动时序的完整保证。保留现场日志再查。 | 不要把模拟器通过当成真机已恢复。 |

更详细的恢复说明与回归表见 [HOGP-RECOVERY.md](HOGP-RECOVERY.md)。

## 10. 回滚

原开发机本地目录 `build/diagnostics/recovery-root/` 会保留已签名归档（具体文件名以当时的 `RELEASE-MANIFEST.json` 和 [QUICKSTART.zh-CN.md](QUICKSTART.zh-CN.md) 为准），例如带启用按钮的成功旧版、大触控板基线、以及当前候选。安装回滚包的方式与第 6 节相同：校验签名和描述文件，再 `devicectl` 安装。不要为了回滚去推送仓库或合并主分支。
