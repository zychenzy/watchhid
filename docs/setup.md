**English** | [简体中文](setup.zh-CN.md)

# Setup

This is the public install path for WatchHID on a Mac you control. It does not reset Bluetooth bonds, and it does not copy an encrypted HOGP bond from another Mac.

Do not print or commit device UDIDs, Bluetooth addresses, provisioning device lists, certificate serials, or Apple ID emails. Put local identifiers only in the gitignored files copied from the templates below.

## 1. Prerequisites

- Full Xcode, not only Command Line Tools
- Developer Mode enabled on the Apple Watch. Operator testing was done on an Apple Watch Ultra 2. Other models are not a verified matrix and are not declared unsupported.
- The iPhone paired with that Watch (a watchOS requirement; WatchHID itself is watch-only and has no companion iPhone app)
- An Apple account that can sign a watchOS app in Xcode: a free Personal Team or a paid Apple Developer Program membership. This project was tested with a free Personal Team; that is an example, not a requirement. Apple documents that free Personal Team App IDs, devices, and provisioning profiles expire 7 days after issuance, after which you rebuild and reinstall: [About your developer account](https://developer.apple.com/help/account/basics/about-your-developer-account/). Do not treat that 7-day cycle as a rule for a paid membership. This project is not an App Store submission.

The macOS login account and the Apple ID used for signing may be different. Do not change the Mac login just to sign.

## 2. Local configuration

From the repository root:

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig
cp Config/local_devices.env.example Config/local_devices.env
```

Fill `DEVELOPMENT_TEAM` in the xcconfig and `WATCH_UDID` in the env file. Those two files are gitignored.

## 3. Signing preflight

```bash
./scripts/check-signing-prereqs.sh
```

If the script reports a missing WWDR G3 intermediate:

```bash
./scripts/check-signing-prereqs.sh --install-wwdr
```

Confirm the login keychain prompt if macOS shows one. That installs Apple’s official intermediate; it does not create a new Development certificate.

Only use Xcode **Manage Certificates… > +** when preflight says there is no signing identity on this Mac. If **+** says a current Development certificate already exists, stop and fix trust. Do not revoke a certificate that another Mac still uses.

## 4. Build a signed Watch app

```bash
./scripts/ship-encrypted-hogp.sh
```

This produces a signed zip under `build/diagnostics/recovery-root/`. It does not install the app.

Confirm any codesign keychain prompt yourself.

## 5. Install

The developer tunnel is not the same thing as a Bluetooth-connected Apple Watch. A `connected` entry in `devicectl list devices` is not sufficient by itself.

When you are ready to install, run **only**:

```bash
./scripts/install-signed-watch-app.sh
```

You may pass the signed zip path as an argument. The script already probes CoreDevice details and DDI services after the list state is `connected`. That is the single readiness gate.

Do **not** run `./scripts/install-signed-watch-app.sh --check-ready` immediately before an install. `--check-ready` is a standalone diagnostic probe for when you are not installing.

Keep the Watch close, awake, unlocked, and screen-on. A nearby unlocked iPhone on the same network can help the developer tunnel; that does not mean a companion app is required.

If install fails with “Failed to allocate RSD device”, CoreDevice 4000, or RemotePairing 1001, wait, confirm the Watch is still unlocked and screen-on, and run the same installer once more. Do not loop, do not reset Bluetooth, and do not change certificates.

## 6. First use

Open WatchHID on the Watch.

Watch-only means WatchHID does not need a companion iPhone app. A paired iPhone is still required by watchOS, and some system privacy settings may still be managed on that iPhone. Apple documents that some Apple Watch privacy settings are shared with iPhone and are changed in the iPhone **Settings** app under **Privacy & Security** (examples there include Location Services, Analytics, Contacts, and Health): [View app settings and storage on Apple Watch](https://support.apple.com/guide/watch/view-app-settings-and-storage-apd31a7d203c/watchos). Apple’s Bluetooth privacy article, which includes Apple Watch, says you can allow or revoke an app’s Bluetooth access in **Settings > Privacy & Security > Bluetooth**: [If an app would like to use Bluetooth on your device](https://support.apple.com/en-us/102267).

If the Watch does not become ready to advertise—for example it stays waiting for a host, or Watch **Settings > Privacy & Security > Bluetooth** controls are unavailable and say that some privacy settings are shared with iPhone—use the paired iPhone’s **Settings** app (this is not a claim that the iPhone **Watch** app can always change the same control):

1. On the paired iPhone, open **Settings > Privacy & Security > Bluetooth**.
2. If WatchHID is listed, enable it.
3. Return to WatchHID on the Watch. Do not reset or unpair system Bluetooth, and do not reinstall the app to change this permission.

This iPhone Settings path has been confirmed to restore WatchHID when the Watch Bluetooth controls were unavailable and showed that shared-settings notice. That is a confirmed case, not a requirement for every watchOS setup. If WatchHID is not in the iPhone Bluetooth privacy list, inspect the current Watch and iPhone privacy state rather than resetting Bluetooth or reinstalling at random.

If macOS shows a Bluetooth pairing prompt, confirm it in the system dialog. Short-drag on the pad, then:

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` means this Mac sees one IOHID node with the app's advertised HID identity (currently `WatchHID` / `Ultra2-R1`) and mouse/pointer usage. Those strings come from the current build, not from the physical Watch model name. It is not proof that the pointer moved. Success is that node plus movement you see yourself. If you change the advertised strings in a local build, point the verify script at them with `WATCHHID_HID_MANUFACTURER` and `WATCHHID_HID_MODEL`.

A new Mac needs its own encrypted HOGP bond. System Apple Watch pairing and iCloud do not copy that bond from another Mac.

## Dialogs you have to confirm

| Situation | What you should do |
|---|---|
| Keychain or codesign prompt | Confirm in the official dialog. Do not paste passwords into chat. |
| WWDR G3 install | Confirm the keychain prompt after `--install-wwdr`. |
| Bluetooth pairing / passkey | Confirm in the macOS system dialog while WatchHID is in the foreground. |
| Keyboard Setup Assistant | Close it. WatchHID does not need identification completed. Do not use another keyboard to identify it. |
