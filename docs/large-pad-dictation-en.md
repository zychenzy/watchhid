# Large pad and English dictation HID

Branch intent for `feature/large-pad-dictation-en-hid`.

- Almost-full Watch touchpad, with a bottom dictation button (`Dictation` / `语音听写` / `語音聽寫`).
- After you tap the button it shows a Dictating state, then Cancel while typable text is being sent. The Watch does not show the captured text.
- System dictation (`presentTextInputController`) types typable English into the focused Mac field only when the English HID keyboard is on.

The English HID keyboard is **off** by default (`UserDefaults` key `wh.keyboardFeature`). On 2026-11-10, enabling the older composite mouse+keyboard Report Map (Report IDs) on a Mac that already bonded the no-Report-ID mouse map made pointer movement vertical-only. Closing Keyboard Setup Assistant did not fix it; turning the toggle off restored the baseline map and the pointer. The current toggle adds a separate keyboard HID service and must leave the mouse Report Map byte-identical. Only US-ASCII is mapped. Do not change the host input source automatically.

As of 2026-11-10 (Asia/Shanghai), pointer movement, same-node `WatchHID` / `Ultra2-R1` identity, and Watch-side dictation capture are confirmed on a second Mac. Typing that captured text into a Mac field without disturbing the mouse is the next check. Wireless iPhone isolation remains open.
