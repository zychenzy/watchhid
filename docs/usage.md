# Using WatchHID

The Watch app must be in the foreground with the screen on. After the Watch sleeps or returns to the clock face, open WatchHID again. You do not need Xcode open, and you do not need the iPhone on a USB cable, for the Mac to receive mouse input.

The Watch UI follows the Watch system language. Only English, Simplified Chinese, and Traditional Chinese are shipped; any other language falls back to English. Change the language in Watch Settings, then reopen WatchHID.

## Mouse

1. Unlock the Mac and move the pointer to a safe blank area of the desktop.
2. Open WatchHID and leave it in the foreground. You should see status text.
3. On a new Mac, if a Bluetooth passkey or pairing prompt appears, confirm it in the system dialog first.
4. Drag on the large pad to move the pointer. A short tap is a left click. A long-press of about 0.55–0.6 seconds is a right click.
5. Status should leave “Waiting for Mac subscription” (or `等待 Mac 系统订阅` in Chinese) and look ready for touch.

Current builds auto-arm the pad when at least one Mac has subscribed to the mouse Report and the scene is active. Settings, system text input, and the preview sheet pause the pad, release held buttons, and drop queued motion.

To confirm identity on this Mac:

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` is same-node identity only. Pointer movement is something you see yourself.

If the pointer does not move, exit WatchHID and open it again before doing anything else. Do not reset Bluetooth or unpair the system Apple Watch.

## Dictation

The bottom button is labeled Dictation (`语音听写` in Chinese). It presents the system text-input interface (`presentTextInputController`). English is the first language to accept.

1. Use the pad to click into whatever you need on the Mac, if you want the insertion point ready. Dictation text stays on the Watch unless you later enable English HID (off by default).
2. Tap `语音听写`.
3. If watchOS opens a keyboard first, use the control at the lower right (keyboard with an ellipsis) and choose the microphone.
4. Speak a short English phrase, then tap system **Done**.
5. The app should show a “dictation result” preview. Tap `完成` to return to the pad, then short-drag once to confirm the mouse still works.

The system input method and recognition language are controlled by watchOS. There is no guarantee that the microphone opens directly every time, or that watchOS remembers the last choice.

**English HID typing into the Mac stays off** unless you explicitly enable it in Settings and accept that the Mac may re-enumerate the HID device. Even then, only US-ASCII is mapped; this is not a way to type Chinese into the Mac.

## What is already confirmed, and what is not

Confirmed on more than one Mac: Watch BLE HID reports can move the system pointer; a short drag and tap work; USB unplug of the iPhone does not stop an already working mouse; same-node identity `WatchHID` / `Ultra2-R1`.

Not fully confirmed: a working mouse while no iPhone is nearby on Wi-Fi (wireless isolation); English HID into a Mac text field; every reconnect and restart combination; live dictation capture on the latest installed build.

Simulator checks cover UI and the system text-input callback only. They do not prove BLE HOGP, cursor movement, or speech recognition. See [SIMULATOR-CHECKS.md](SIMULATOR-CHECKS.md).
