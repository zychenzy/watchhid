# Usage

WatchHID is a watch-only app. Pointer, clicks, Crown scrolling, and system dictation do not require an iPhone app. A paired iPhone may still be needed for watchOS itself or for the developer tunnel used during install.

## Trackpad

- Drag to move the pointer.
- Tap for a left click.
- Hold for a right click.
- The Digital Crown scrolls vertically using the existing mouse wheel field. It works from the focused pad with a generic Digital Crown, not the Ultra Action button.

Input is sent only while WatchHID is in the foreground with the screen on. After the Watch sleeps or returns to the clock face, open the app again. Settings and the system text-input sheet pause the pad, release held buttons, and drop queued motion and wheel. When you return to the pad, start a new gesture.

## Output device

Reports go to **one** subscribed host at a time. In Settings, subscribed hosts are listed as Device 1, Device 2, and so on. Those numbers stay with the same connection. They are not a Mac or iPhone label; the Watch cannot reliably tell the operating system.

Select a device, then tap Test or drag on the pad and watch that host. **Ready** means the selected host has subscribed, not that you already saw the pointer move.

If the saved device is away and only one other host is connected, that host is used until you pick again or the saved one returns. If more than one host is listed and you are not sure which is which, pick Device 1, test, then try Device 2.

## English keyboard and dictation

English keyboard HID is **off** by default. Turning it on adds a separate keyboard service and does not change the baseline mouse Report Map.

If Keyboard Setup Assistant appears, close it. WatchHID does not need that identification completed, and you should not identify it using another keyboard. There is no official guaranteed way to prevent the assistant.

The bottom microphone button presents the **system** text-input interface (`presentTextInputController`, `allowedInputMode: .plain`). `.plain` means typable text from dictation or suggestions, without emoji. It does **not** force the sheet to open on dictation. The system chooses the initial method; a keyboard or Scribble may appear first. If that happens, use the input control on the system sheet (usually at the lower right) and choose the microphone.

After you accept a result with the system Done control, typable English is typed into the focused Mac field when the keyboard HID is on. The Watch does not show the captured text. Chinese and other non-ASCII characters are skipped. While text is being sent, the button can cancel that send.

Messages and Siri dictation on the Watch are separate system features. They do not prove that the WatchHID sheet will open on the microphone.

## Settings

Settings include pause-touch, the English keyboard toggle, output selection, and short help for dictation and the keyboard. There is no scan, log, or test-checklist console in the normal Watch UI. On-device diagnostic files, if present, stay in the app container and are not a public log dump.
