# WatchHID：回来后试用

## 当前候选
大触控板 + 底部「语音听写」。只有前台且指定 Mac 订阅时才接收新触摸；语音和设置界面会暂停触控。英文键盘默认关闭，请先不要开启。

## 一次验收
1. 唤醒并解锁 Mac 到安全空桌面；在手表上**手动打开 WatchHID**，确认它留在前台并能看见状态。首次在一台新 Mac 上使用时，若系统弹出 passkey / 蓝牙配对确认，先在这台 Mac 的对话框里完成确认，再继续下面的短滑。这是设置的一步，不是取消手表的系统配对，也不需要重置蓝牙。只完成弹窗或只看到已连接的 HID BLE，都不等于指针已经可用。
2. 在大触控板上短滑，观察指针移动；轻点为左键，原地长按约0.55秒为右键。
3. 点底部**语音听写**。如果先出现键盘，点右下角「键盘＋省略号」，再选麦克风。
4. 说一句短话，点系统 **Done**。应用应显示「听写结果」，点**完成**返回触控板，再短滑。

文字只显示在手表，不会自动输入 Mac。系统输入方式和识别语言由 watchOS 控制；目前不能保证每次直接进入麦克风，也没有验证它一定会记住上次选择。

## 已经通过 / 仍需注意
- 已验收：拔掉 iPhone USB 后，真实 Watch BLE HID 报告仍驱动 Mac 光标；大触控板移动；用户确认系统麦克风可用。
- 未验收：完全隔离附近无线 iPhone、英文 HID 输入 Mac、所有重启/重连组合、当前最后一次安装后的再次短滑。
- 重装或失活时仍可能出现 ATT242，导致 Mac 尚未重新创建鼠标节点。若指针不动，先退出并手动重新打开 WatchHID；若仍失败，保留现场日志供排查。**不要为了试用取消配对、清蓝牙缓存或重置系统蓝牙。**
- 手表离开 Mac 范围后，远程开发连接不可用是正常的，不代表 USB 运行独立性失效。

新 Mac 上要先具备完整 Xcode 和手表开发连接，才能安装这些已签名包；系统登录账号可以和 Xcode 签名用的 Apple ID 不同。开发安装通道和蓝牙连接不是一回事：手表蓝牙已连接时，`devicectl` 仍可能是 `unavailable`。这时把手表点亮解锁，把配对的 iPhone 拿近并连同一 Wi-Fi（不必插线），等到手表显示为 `connected`，再运行 `./scripts/install-signed-watch-app.sh`。2026-11-10 11:54（北京时间）曾在未插 USB、同一 Wi-Fi 且 iPhone 已解锁时无线装包成功；这不代表 iPhone 永远必需，也不代表无线隔离已验证。同日稍后，这台新 Mac 已完成加密配对并创建了 HID 设备，但身份是系统 Apple Watch，短滑后指针没有移动，不能宣称路径已经快速可靠。不要从其他电脑复制蓝牙绑定，也不要重置刚刚完成的绑定。若要重新构建，可在这台 Mac 按 [SETUP.zh-CN.md](SETUP.zh-CN.md) 第 4 节创建本机 Apple Development 证书（不必回到原先的签名机，也不要拷私钥），再运行 `./scripts/ship-encrypted-hogp.sh`。打开应用并确认配对后，跑 `./scripts/verify-hogp-mouse.sh`；脚本的 NODE_OK 只表示同节点身份，指针移动要你自己看见。手表若一直显示 `等待 Mac 系统订阅`，也不等于这台 Mac 的订阅已被应用接受。本机签名只在这台电脑负责构建时才是必要步骤。出门后的最短步骤见 [RETURN-CHECKLIST.zh-CN.md](RETURN-CHECKLIST.zh-CN.md)。当天证据见 [new-mac-hogp-2026-11-10.zh-CN.md](new-mac-hogp-2026-11-10.zh-CN.md)。详见 [SETUP.zh-CN.md](SETUP.zh-CN.md) 和项目 skill [watchhid-new-mac-hogp](../.cursor/skills/watchhid-new-mac-hogp/SKILL.md)。

## 本地包与回滚
Mac mini：`~/projects/watchhid/build/diagnostics/recovery-root/`
- `WatchHID-return-home-candidate.zip`：整理后的可装候选，源码8db3f5d；新增测试入口仅编译到模拟器，未重新装到离家的手表。
- `WatchHID-voice-primary.zip`：目前最后装到手表的版本，源码19e2b13。
- `WatchHID-large-static.zip`：大触控板成功基线，源码3d714db。
- `WatchHID-accepted-static-rollback.zip`：带启用按钮的成功旧版，源码6d62b8e。

这些是已签名 watchOS `.app` 的归档，不是可双击安装的 Mac 应用。需要正常 Xcode/CoreDevice 手表开发连接；免费签名有效期有限，必要时用现有工程重新签名。

无人在场的模拟器测试只能证明对应 UI/状态逻辑，不证明真实 BLE HOGP、系统光标因果或语音 ASR。详见 [模拟器测试报告](SIMULATOR-CHECKS.md)。
