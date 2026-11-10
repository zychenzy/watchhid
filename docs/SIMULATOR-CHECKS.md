# Simulator checks and limits

## Environment
the development Mac uses existing watchOS27.2 runtime24S118, simulated Apple Watch Ultra4(49mm), UDID SIMULATOR_UDID. Physical device is Ultra2, so this is not an exact hardware match. No runtime downloaded. Free disk before8.1GiB; after boot/build about7.4GiB.

## Actually exercised
- Current watchOS Simulator build succeeded. Headless simctl install and launch succeeded; process liveness was checked.
- Settled main screenshot shows large pad and orange语音听写 button. It says等待Mac系统订阅 because simulator CoreBluetooth peripheral state is unsupported. This is expected, NOT BLE HID acceptance.
- Simulator-only --simulator-text-entry invokes the same actual public system input method as the button. Screenshot confirms the system keyboard appears. That initial smoke check proved presentation only; actual typed completion was subsequently verified below.
- --simulator-sample-preview presents the explicit synthetic text SIMULATOR SAMPLE—not speech. Screenshot confirms preview layout, Done action visibility, and no automatic Mac input. This is mock data, NOT ASR.
- --simulator-sample-preview --simulator-dismiss-preview clears preview programmatically after3seconds; a separate screenshot/log records return to the main pad. This is a state/rendering check, not a physical tap test.
- Pure mouse/keyboard/metadata tests and12 existing evidence-gate tests passed. Coverage includes tap-left, hold-right/release, inactive release, subscription loss, no stale-motion replay, cached metadata bytes and report-map modes.

## Cannot claim from these checks
No real BLE HOGP or system Mac cursor success, no voice ASR, no microphone availability, no proof of physical drag/tap recognition, no guarantee watchOS remembers the microphone input mode. Simulator-only arguments are compiled out of physical-device builds; no mock data runs by default.

## Actual system completion and cancellation: passed
Official watchOS XCTest UI tests ran on the same already-booted simulator, using the public XCTest runner rather than scripting the Mac desktop. Both tests passed at09:14 HKT:
1. `testTypedSystemCompletionAndReturn`: launch actual system text entry, type the harmless word sequence `watch test`, tap the real system Done button, assert the real callback produced the exact text in听写结果, tap完成, assert return to the touchpad with preview dismissed. At09:14:42 HKT app log recorded `Dictation captured chars=10 ascii=10 (preview held; not typed)`. Screenshots independently show the expected String and returned main panel.
2. `testSystemCancelReturnsWithoutPreview`: tap actual system Cancel, assert main panel returns and no preview appears. App log recorded canceled/empty at09:14:35 HKT.

This is real **typed text-input completion**, not the earlier synthetic preview. It does not test speech ASR, physical Watch BLE, cursor movement, or microphone-mode persistence. No Mac input is sent.

Reproduce using scheme `WatchHIDSimulatorChecks` and destination `platform=watchOS Simulator,id=SIMULATOR_UDID`; run build-for-testing then test-without-building, with an enclosing210-second timeout. Tests are in `Tests/WatchHIDUITests/SystemTextEntryTests.swift`.

## Evidence
the development Mac path `build/diagnostics/recovery-root/`:
`simulator-main-ready.png`, `simulator-system-text-entry.png`, `simulator-synthetic-preview.png`, `simulator-return-to-pad.png`, corresponding log files and `build-watchsim-harness.log`.

Actual UI result: `system-text-entry-ui.xcresult`, runner log `run-system-text-ui.log`, real completion app log `simulator-real-system-completion.log`. Readable screenshot/hierarchy copies are under `system-text-ui/`: `01-real-system-keyboard`, `02-typed-not-speech`, `03-real-completion-preview`, `04-return-after-done`, `05-return-after-cancel`.
