# Using WatchHID

The Watch app must be in the foreground with the screen on. After the Watch sleeps or returns to the clock face, open WatchHID again. You do not need Xcode open, and you do not need the iPhone on a USB cable, for the Mac to receive mouse input.

The Watch UI follows the Watch system language. Only English, Simplified Chinese, and Traditional Chinese are shipped; any other language falls back to English. Change the language in Watch Settings, then reopen WatchHID.

## Mouse

1. Unlock the Mac and move the pointer to a safe blank area of the desktop.
2. Open WatchHID and leave it in the foreground. You should see status text.
3. On a new Mac, if a Bluetooth passkey or pairing prompt appears, confirm it in the system dialog first.
4. Drag on the large pad to move the pointer. A short tap is a left click. A long-press of about 0.55–0.6 seconds is a right click.
5. Status should leave “Waiting for Mac subscription” (or `等待 Mac 系统订阅` in Chinese) and look ready for touch.

Current builds auto-arm the pad when at least one Mac has subscribed to the mouse Report and the scene is active. Settings and system text input pause the pad, release held buttons, and drop queued motion. Sending keyboard text also pauses the pad until it finishes or you cancel.

To confirm identity on this Mac:

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` is same-node identity only. Pointer movement is something you see yourself.

If the pointer does not move, exit WatchHID and open it again before doing anything else. Do not reset Bluetooth or unpair the system Apple Watch.

## Output

Reports go to only one subscribed host at a time. The Settings list shows the hosts that have actually subscribed, labeled Device 1, Device 2, and so on. Those numbers stay with the same connection. They are not “Mac” or “iPhone” labels: the Watch is not given a reliable operating-system name, so the app does not guess.

1. Open Settings from the control at the top left of the pad.
2. If more than one host is listed and none is selected, status is “Choose output” (or `请选择输出` / `請選擇輸出`). Pick one. The pad does not send reports until a host can be resolved.
3. Tap Test to send a small pointer movement to that host only, or drag on the pad. Watch the machine you care about. Test is not a click.
4. Ready means the selected host has subscribed. It does not mean you have already seen the pointer move on that device.

The selected host is remembered. If it reconnects, reports go back to it. If it is away and only one other host is connected, that remaining host is used temporarily. If it is away and two or more hosts are still connected, pick one again. A previous “Automatic (prefer Mac)” mode and manual Mac/iPhone labels are no longer used; stale labels are cleared on launch.

## Dictation

The bottom button is labeled Dictation (`语音听写` in Chinese). It presents the system text-input interface (`presentTextInputController`). After you accept the result, typable English is typed into the focused Mac field, including after the system sheet briefly backgrounds the Watch app. The Watch does not show the captured text. While the system interface is up, the button reads Dictating (`听写中`). While text is being sent, it becomes Cancel (`取消`).

1. Use the pad to click into a Mac text field so the insertion point is ready.
2. Tap Dictation.
3. If watchOS opens a keyboard first, use the control at the lower right (keyboard with an ellipsis) and choose the microphone.
4. Speak a short English phrase, then tap system **Done**.
5. The Watch returns to the pad without a result preview. If the keyboard is subscribed, typable characters are sent to the Mac. Tap Cancel to stop a send that is still in progress. Then short-drag once to confirm the mouse still works.

The system input method and recognition language are controlled by watchOS. There is no guarantee that the microphone opens directly every time, or that watchOS remembers the last choice.

English HID typing into the Mac is **off** by default. A composite mouse-and-keyboard Report Map (Report IDs) must not be used on a Mac that already bonded the no-Report-ID mouse map: on 2026-11-10 that made pointer movement vertical-only. Turning the keyboard off restored the baseline map and the pointer. The current Settings toggle adds a separate keyboard HID service and leaves the mouse Report Map unchanged.

Only US-ASCII is mapped; Chinese and other non-ASCII characters are skipped. This is not a way to type Chinese into the Mac.

If a Keyboard Setup Assistant appears, close it. WatchHID does not need you to complete keyboard-type identification. That reminder is unchanged: the window can still appear, and closing it remains the supported response. [Apple’s Mac User Guide](https://support.apple.com/guide/mac-help/specify-a-keyboard-type-mchlp2886/mac) says this assistant opens automatically when macOS connects a keyboard it does not immediately recognize, so you can specify ANSI, ISO, or JIS. There is no official WatchHID or macOS setting documented here that guarantees the window will not appear while a keyboard HID service is present.

On 2026-11-10 the operator clarified that Continue and a key on another keyboard happened earlier on another Mac, not on the the development Mac, where they only closed the assistant. Reopening Keyboard Setup Assistant on the mini later showed a Logitech device, not WatchHID; Continue was not pressed. See [evidence/mini-ksa-ab-baseline-2026-11-10.md](evidence/mini-ksa-ab-baseline-2026-11-10.md).

Do not use an unrelated physical keyboard to identify WatchHID in that assistant. Pressing Continue and then a key does not change WatchHID firmware or the Watch app, but it can write a host keyboard-type setting, and this project has not tested what finishing that identification — especially with a key from another keyboard — does to the current separate keyboard service. Do not assume there is no effect without a check. If you already pressed Continue or a key, do not assume the Apple Watch or the bond is damaged, and do not reset Bluetooth or unpair to undo it. Check pointer movement, click, and English dictation typing, and report the actual symptom if something is wrong.

The earlier vertical-only pointer bug coincided with publishing a composite mouse+keyboard Report Map on a Mac that already bonded the baseline no-Report-ID mouse map. Closing Keyboard Setup Assistant did not fix it; restoring the baseline map did. See [evidence/composite-keyboard-vertical-only-2026-11-10.md](evidence/composite-keyboard-vertical-only-2026-11-10.md). The current separate keyboard service leaves the mouse Report Map unchanged and is meant to avoid that same trigger. That is a different cause from any unproven host-side effect of completing the assistant on the current keyboard path.

Do not disable or move the system assistant, do not edit `/Library` keyboard-type preferences, and do not change the working mouse HID identity or Report Map to spoof a built-in Apple keyboard.

English keyboard HID is off by default, and the separate keyboard service is added only after that toggle is on and the mouse Report is subscribed. Turning the toggle off leaves already published services in place so the existing mouse bond is not torn down. If the pointer ever goes wrong again, turn English keyboard HID off in Settings, and do not reset Bluetooth or unpair the system Apple Watch.

## What is already confirmed, and what is not

Confirmed on more than one Mac: Watch BLE HID reports can move the system pointer; a short drag and tap work; USB unplug of the iPhone does not stop an already working mouse; same-node identity `WatchHID` / `Ultra2-R1`; system dictation can capture text on the Watch.

The operator has confirmed that the Watch could control the iPhone while outdoors, several minutes away from the Mac and on a different Wi-Fi network. That is a real user confirmation; it has not been instrumented on this Mac.

On the evening of 2026-11-10, after the local output-picker package was installed on the the development Mac, the operator said the Apple Watch was normal and could work. That acceptance does not separately confirm iPhone and Mac output, one after the other. On that Mac, `verify-hogp-mouse.sh` reported `NODE_OK`. Details: [evidence/home-mini-neutral-picker-2026-11-10.md](evidence/home-mini-neutral-picker-2026-11-10.md).

Not fully confirmed: typing dictation into a Mac text field through a separate keyboard HID service; a working mouse while no iPhone is nearby on Wi-Fi as a formal isolation test; every reconnect and restart combination; which listed Device N is the iPhone or the Mac without a local test; a supported way to prevent Keyboard Setup Assistant while the keyboard service is present.

Simulator checks cover UI and the system text-input callback only. They do not prove BLE HOGP, cursor movement, or speech recognition. See [SIMULATOR-CHECKS.md](SIMULATOR-CHECKS.md).
