# Large pad and English dictation HID

Branch intent for `feature/large-pad-dictation-en-hid`.

- Almost-full Watch touchpad, with a bottom dictation button (`Dictation` / `语音听写` / `語音聽寫`).
- After you tap the button it shows a Dictating state, then Cancel while typable text is being sent. The Watch does not show the captured text.
- System dictation (`presentTextInputController`) types typable English into the focused Mac field when the English HID keyboard is on.

The English HID keyboard is **on** by default (`UserDefaults` key `wh.keyboardFeature`; a missing key means on). This republishes a composite mouse and keyboard Report Map and may make the Mac re-enumerate the device. Turning the Settings toggle off restores the baseline mouse map. Only US-ASCII is mapped. Do not change the host input source automatically.

As of 2026-11-10 (Asia/Shanghai), pointer movement, same-node `WatchHID` / `Ultra2-R1` identity, and Watch-side dictation capture are confirmed on a second Mac. Typing that captured text into a Mac field is the next check. Wireless iPhone isolation remains open.
