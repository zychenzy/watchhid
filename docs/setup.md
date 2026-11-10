# Setup

This is the public install path for WatchHID on a Mac you control. It does not reset Bluetooth bonds, and it does not copy an encrypted HOGP bond from another Mac.

Do not print or commit device UDIDs, Bluetooth addresses, provisioning device lists, certificate serials, or Apple ID emails. Put local identifiers only in the gitignored files copied from the templates below.

## 1. Prerequisites

- Full Xcode, not only Command Line Tools
- Developer Mode enabled on the Apple Watch
- The iPhone paired with that Watch (a watchOS requirement; WatchHID itself is watch-only and has no companion iPhone app)
- An Apple Developer account for signing

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

Open WatchHID on the Watch. If macOS shows a Bluetooth pairing prompt, confirm it in the system dialog. Short-drag on the pad, then:

```bash
./scripts/verify-hogp-mouse.sh
```

`NODE_OK` means this Mac sees the WatchHID mouse node (`WatchHID` / `Ultra2-R1`, mouse/pointer usage). It is not proof that the pointer moved. Success is that node plus movement you see yourself.

A new Mac needs its own encrypted HOGP bond. System Apple Watch pairing and iCloud do not copy that bond from another Mac.

## Dialogs you have to confirm

| Situation | What you should do |
|---|---|
| Keychain or codesign prompt | Confirm in the official dialog. Do not paste passwords into chat. |
| WWDR G3 install | Confirm the keychain prompt after `--install-wwdr`. |
| Bluetooth pairing / passkey | Confirm in the macOS system dialog while WatchHID is in the foreground. |
| Keyboard Setup Assistant | Close it. WatchHID does not need identification completed. Do not use another keyboard to identify it. |
