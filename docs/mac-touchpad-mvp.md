# Mac BLE touchpad MVP — installed / awaiting intentional user input

Times: Asia/Hong_Kong (HKT, UTC+8), 2026-11-09 around22:59–23:01.

## Delivered
- Explicit `启用输入` / `停用输入`, large non-scrolling touch surface, independent clearly labeled `左键单击` button.
- Default disabled; finger-down alone does not move. Drag is relative4-byte Bluetooth HID (buttons,X,Y,wheel),1.8× point gain,30Hz cap, signed±127 per report, fractional residual accumulation and bounded±254 backlog. Finger-up discards unsent movement, no inertia/replay.
- Scene inactive/background/disappearance, loss of target subscription, stop, or transmission backpressure disarms and discards movement. Returning active never auto-arms.
- Only the previously verified Mac central F7A703F6… as sole Report subscriber can receive new input. Unknown/additional subscribers fail closed; this MVP is targeted to this Mac mini, not arbitrary hosts.
- Explicit click down then80ms up; no click on pad taps. A failed release is held as safety completion, blocks enabling, and can finish on the existing peripheral-ready callback or the same Mac's resubscription. That neutral is only completion of an already user-requested click, never startup/test input. Bluetooth queue acceptance is not delivery acknowledgment; no guarantee if host disconnects.
- Normal App launch prepares the same `standard128-dynamic` service recipe. No auto input, diagnostic nudge, neutral-on-subscribe, Mac helper App, accessibility permission, wrist IMU, or runtime extension.
- Independent callback entry/response-return + bounded JSONL from preceding audit is in this signed build. Offline evidence gate remains under `scripts/assess_live_read.py` (not falsely described as an installed live iPhone orchestrator). Actual input has independent active/explicit-enable/sole-Mac-subscriber/touch gates.

## Verification
- `logic-tests.txt`:24 pure state/encoding/rate-limit/deadman/click checks passed. No Bluetooth or system input in those tests.
- Existing12 evidence-gate tests passed.
- Two-job existing-cache free-signed Watch build succeeded ONCE (`signed-build.log`); signature verification passed; install ONCE succeeded (`install.json`). No phone install, phoneUSB/unlock check, provisioning change, unpairing, system Bluetooth/safety/network change, commit or push.
- One normal activation (no terminate-existing) returned new PID828 and new installed bundle path462C3D0E… (`launch.json`).
- First immediate screenshot was the old launch snapshot/spinner; it was NOT claimed new UI success. After bounded startup, second supported screenshot **visually confirmed** new Mac触控板 UI: `Mac 已订阅 · 待启用`, green enable button, gray pad with `先启用，再拖动`, disabled left button. `watch-ui-after-startup.png`,410×502.
- Before startup IOHID exact-descriptor match was absent. After startup it is present: IOHIDUserDevice ID4296004128, Transport Bluetooth Low Energy, Manufacturer WatchHID, Model Ultra2-R1, UsagePage1/Usage2, MaxInputReportSize4, exact52-byte report map. `mac-iohid-after-startup.plist` + `mac-iohid-after-startup-matches.json`. This is system mouse enumeration, not just an App GATT count.
- No automated enable, drag, click, relative report, test input, or cursor movement was performed. Human usability/movement of this version remains unverified.
- Resource precheck:~17GiB free, load~3.2; reused derived data, one signed build, no cleanup/deletion. Runtime factory `.m/.h` and Shared HIDDescriptors SHA256 unchanged (`protected-hashes-unchanged.json`). Prior files and this-round patch preserved here.
- Whole-repo `git diff --check` reports an older blank line at EOF in HIDDescriptors.swift; protected source intentionally left unchanged. This round's edited/new files pass trailing-whitespace check.

## Actual transient diagnostic failures
Watch App log copy hit its12s timeout; subsequent process query reported CoreDevice RSD allocation error0xE8000003. No alternate low-level data route, kill, install retry or launch retry was used. Installed-app query succeeded; later supported screenshot succeeded and Mac IOHID appeared. Therefore these failures limit fresh exported Watch log evidence, not the observed installed UI/system node. Report subscription currently corroborated by actual UI; no new exported independent ATT trace claimed.

## Single consolidated action for Z
On the Mac, choose a safe blank area with nothing dangerous under the pointer. On Watch, open WatchHID normally if needed. When it says `Mac 已订阅 · 待启用`, tap `启用输入`, drag a short distance on the large pad, lift, then deliberately press `左键单击` once only if that location is safe. Tap `停用输入` when done. This is finger touchpad control, not wrist motion. There is no need to keep phone plugged into Mac or unlock it for actual BLE HID input.

Foreground/screen-off limit is real: this version stops on inactive/background and may require reopening/re-enabling after screen sleep/return-to-clock. No guarantee of a continuous75s foreground window, screen-off operation or stable all-night background execution; no fake workout/category or unsupported timeout API. The one-time build/install already completed directly to Watch; no remaining phoneUSB installation blocker. Future developer connection may still depend on normal paired-device proximity/connectivity; no network settings changed or transport assumption made.

## Parent Linear paragraph (executor did not publish)
今晚Mac直接BLE鼠标MVP已本地完成并免费签名安装Watch一次：显式启用的大手指触控板、独立左键、30Hz限速/符号限幅/分数累积，抬指清空，订阅丢失及inactive/background停发并需重新启用；保留既有standard128-dynamic配方/runtime工厂，合入独立ATT回调证据。24项纯逻辑测试与12项证据闸门测试通过。真机截图已确认新界面“Mac已订阅·待启用”，Mac真实BLE IOHID鼠标节点已重新出现，Manufacturer=WatchHID、Model=Ultra2-R1、4字节且ReportDescriptor精确匹配；未自动发送位移/点击，本版交互待Z一次安全短拖及明确左键验证。无需手机USB/解锁；不承诺熄屏后台或75s连续可用。日志导出曾12s超时、进程查询曾RSD错误，后续截图及IOHID检查成功，未重装/杀进程绕过。
