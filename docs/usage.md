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

## Dictation

The bottom button is labeled Dictation (`语音听写` in Chinese). It presents the system text-input interface (`presentTextInputController`). After you accept the result, typable English is typed into the focused Mac field. The Watch does not show the captured text. While the system interface is up, the button reads Dictating (`听写中`). While text is being sent, it becomes Cancel (`取消`).

1. Use the pad to click into a Mac text field so the insertion point is ready.
2. Tap Dictation.
3. If watchOS opens a keyboard first, use the control at the lower right (keyboard with an ellipsis) and choose the microphone.
4. Speak a short English phrase, then tap system **Done**.
5. The Watch returns to the pad without a result preview. If the keyboard is subscribed, typable characters are sent to the Mac. Tap Cancel to stop a send that is still in progress. Then short-drag once to confirm the mouse still works.

The system input method and recognition language are controlled by watchOS. There is no guarantee that the microphone opens directly every time, or that watchOS remembers the last choice.

English HID typing into the Mac is on by default. Turning it on republishes a composite mouse and keyboard descriptor, and the Mac may re-enumerate the HID device. Only US-ASCII is mapped; Chinese and other non-ASCII characters are skipped. This is not a way to type Chinese into the Mac. You can turn the keyboard off in Settings to restore the baseline mouse map. If a Bluetooth prompt appears after install, confirm it in the system dialog. Do not reset Bluetooth or unpair the system Apple Watch.

## What is already confirmed, and what is not

Confirmed on more than one Mac: Watch BLE HID reports can move the system pointer; a short drag and tap work; USB unplug of the iPhone does not stop an already working mouse; same-node identity `WatchHID` / `Ultra2-R1`; system dictation can capture text on the Watch.

Not fully confirmed: typing dictation into a Mac text field (English HID, now on by default); a working mouse while no iPhone is nearby on Wi-Fi (wireless isolation); every reconnect and restart combination after the composite keyboard map is published.

Simulator checks cover UI and the system text-input callback only. They do not prove BLE HOGP, cursor movement, or speech recognition. See [SIMULATOR-CHECKS.md](SIMULATOR-CHECKS.md).
