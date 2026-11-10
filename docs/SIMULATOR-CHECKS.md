# Simulator checks

These checks exercise the system text-input sheet in the watchOS Simulator. They are not speech recognition, microphone, physical touch, or BLE tests.

## What they cover

The `WatchHIDSimulatorChecks` scheme runs official XCTest UI tests in `Tests/WatchHIDUITests/SystemTextEntryTests.swift`:

1. `testTypedSystemCompletionAndReturn` — present the real system text-input sheet, type a short harmless phrase, tap the system Done button, and assert that the Watch returns to the pad without showing a captured-text preview.
2. `testSystemCancelReturnsWithoutPreview` — tap the system Cancel control and assert that the pad returns with no preview.

Current production behavior does not show the captured text on the Watch. Typable English is meant to be sent to the focused Mac field on a physical device when the keyboard HID is on; the simulator checks do not send Mac HID input and do not prove that path.

A CoreBluetooth peripheral is not supported in the simulator, so a waiting or unsubscribed pad status there is expected and is not HID acceptance.

Simulator-only launch arguments used by these checks are compiled out of physical-device builds.

## What they cannot claim

- On-device speech recognition or microphone behavior
- That watchOS will open the sheet on dictation rather than keyboard or Scribble
- BLE HOGP, pointer movement, or clicks
- Physical Digital Crown or trackpad gestures

## How to run

Use the `WatchHIDSimulatorChecks` scheme and a watchOS Simulator destination already installed on the Mac. Do not commit a simulator UDID.

```bash
xcodegen generate
# Then run the WatchHIDSimulatorChecks scheme from Xcode, or an equivalent
# xcodebuild test against a local watchOS Simulator destination.
```
