# Architecture notes

WatchHID is a watch-only Apple Watch application. It advertises a Bluetooth Low Energy HID-over-GATT (HOGP) mouse. When English typing is enabled, the keyboard is a **separate** HID service. The baseline mouse report stays a 4-byte relative report (buttons, X, Y, wheel) with no Report ID.

The host does not run a WatchHID helper. A Mac that bonds and subscribes is expected to treat the Watch as a system HID mouse through the normal HOGP stack.

watchOS marks `CBPeripheralManager` and the usual peripheral setup APIs `API_UNAVAILABLE(watchos)`. This project creates those objects through an Objective-C runtime factory. That path has worked on the setups that were actually tested. It is not a supported Apple API, not an App Store review path, and not a promise that future watchOS releases will keep accepting it.

Input is sent only while WatchHID is in the foreground with the screen on.

## Related project (comparison only)

[darwin-bt-remote](https://github.com/jqssun/darwin-bt-remote) is a separate open-source project that turns an iPhone, iPad, or Mac into a Bluetooth HID controller. **This repository does not copy its implementation or its documentation.** That project is licensed AGPL-3.0; the notes below are an architecture comparison written in our own words.

| | WatchHID | darwin-bt-remote |
|---|---|---|
| Controller device | Apple Watch app | iPhone, iPad, or Mac, as that project documents |
| Radio / profile used here | Bluetooth LE HOGP only | That project documents both BLE HOGP and, on macOS, Classic Bluetooth HID |
| Peripheral API | Official watchOS API is unavailable; runtime factory | Official device-role APIs on iOS and macOS, as that project documents |
| Host helper | None | None, as that project documents |
| What has been verified | Operator-confirmed setups only; not a general OS matrix | That project publishes its own compatibility claims; they are not reused or re-tested here |

The shared idea is that an Apple device can present a standard HID to a host. The important differences for this repository are the controller (a Watch app), the watchOS API gap, and the narrower, explicitly non-matrix test record. Do not treat the two codebases as equivalent, and do not copy source between them.
