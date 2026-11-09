# Large pad + EN dictation HID (feature branch)

Branch: `feature/large-pad-dictation-en-hid` (from `a3c9eaf`).

## Intent
- Almost-full Watch touchpad; bottom **听写** button.
- Drag = move; short tap = left click; long-press = right click (mutually exclusive).
- No large enable button: auto-arm when Mac Report subscribed + scene active; pause via settings.
- System dictation → review sheet → optional English ASCII via experimental HID keyboard.

## Keyboard safety
- **Default OFF** (`UserDefaults wh.keyboardFeature`). Mouse Report Map stays the accepted no-Report-ID baseline.
- Enabling keyboard republishes composite Report Map (mouse ID1 + keyboard ID2). May require Mac re-enumeration. Toggle off to roll back.
- Only US-ASCII mapped; non-ASCII skipped (counted), never remapped into wrong glyphs.
- Chinese/IME: HID keyboard is scan codes, not Unicode. Do not change host input source automatically.

## Verification so far (Asia/Shanghai)
- Logic tests: pass (`build/diagnostics/large-pad/logic-tests.txt`).
- Signed Watch + iPhone-embed builds: succeed.
- iPhone install: `com.zy.watchhid` installed (embed includes Watch app).
- Direct Watch CoreDevice install: **blocked** — Watch tunnel `unavailable` / error 4016. Needs Watch awake + near Mac/iPhone.
- Mouse regression / keyboard IOHID / live dictation: **pending device**.

## User steps remaining
1. Wake Ultra 2 near iPhone/Mac; open WatchHID on Watch (or wait for companion install).
2. Confirm status becomes touch-ready; drag/tap/long-press on a safe empty desktop area.
3. Settings → enable **英文键盘 HID** only if willing to rebind; click a **safe empty text field**; 听写 → review → 发送英文.
4. If mouse breaks after keyboard ON: turn keyboard OFF in settings (republish baseline).
