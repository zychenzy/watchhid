# Large pad and optional English dictation HID

Branch intent for `feature/large-pad-dictation-en-hid`.

- Almost-full Watch touchpad, with a bottom dictation button (`语音听写` in the current UI).
- Drag moves the pointer; a short tap is a left click; a long-press of about 0.55–0.6 seconds is a right click.
- The pad auto-arms when a Mac has subscribed to the mouse Report and the scene is active. Settings and system text input pause the pad.
- System dictation presents captured text on the Watch for review. It does not type into the Mac unless the optional English HID keyboard is enabled.

The English HID keyboard is **off** by default (`UserDefaults` key `wh.keyboardFeature`). The accepted mouse Report Map stays the no-Report-ID baseline until that toggle is turned on, which republishes a composite map and may make the Mac re-enumerate the device. Only US-ASCII is mapped. Do not change the host input source automatically.

Operator steps: [usage.md](usage.md). Setup on a new Mac: [setup.md](setup.md).

As of 2026-11-10 (Asia/Shanghai), pointer movement and same-node `WatchHID` / `Ultra2-R1` identity are confirmed on a second Mac after installing current source. Live dictation on that build, wireless iPhone isolation, and English HID into a Mac field remain open.
