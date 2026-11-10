# Set up WatchHID on a new Mac

This is the reusable path for any Mac and any compatible Apple Watch. After you copy the project onto this Mac, build and sign here. Do not copy private keys, Bluetooth settings, or an HOGP bond from another Mac.

An encrypted HOGP bond exists only between this Watch and this Mac’s Bluetooth controller. The steps are reusable; the keys are not.

Do not print or commit device UDIDs, Bluetooth addresses, provisioning device lists, certificate serials, or Apple ID emails. Put local identifiers only in the gitignored files named below. Type passwords and verification codes only in official system or Apple dialogs, never into chat or a log.

## Two different connections

| Connection | What it is for | Ready when |
|---|---|---|
| CoreDevice developer tunnel (`devicectl`) | Install or launch the Watch app | `xcrun devicectl list devices` shows this Watch as `connected` |
| Bluetooth LE HOGP | The Watch acting as a system mouse | WatchHID is in the foreground, and this Mac has an encrypted HID bond with it |

A Bluetooth-connected Apple Watch, including one labeled HID BLE, is not enough to install the app. A connected developer tunnel is not enough to prove the pointer works.

## 1. Install Xcode

Check this Mac’s system version with `sw_vers`, then install a full Xcode that [Apple’s SDK table](https://developer.apple.com/xcode/system-requirements/) supports. Command Line Tools alone are not enough: `xcrun devicectl` may only tell you to install Xcode.

Install from the Mac App Store or from [Apple Developer downloads](https://developer.apple.com/download/all/?q=Xcode). You can stay signed into the App Store with the everyday Apple ID. Then:

```bash
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -runFirstLaunch
xcodebuild -version
xcrun devicectl list devices
```

**You confirm:** the administrator password and any first-launch license dialogs.

## 2. Add the signing Apple ID in Xcode

The macOS / iCloud login on this Mac may be different from the Apple ID used to sign the app. Do not sign out of macOS or switch iCloud just to develop.

1. Keep the current macOS login unchanged.
2. Open **Xcode > Settings > Accounts** and add the project’s developer Apple ID (a free personal team is enough).
3. Complete sign-in and two-factor authentication in the official dialogs.

**You confirm:** Apple ID password, two-factor code, and any account permission prompts.

## 3. Create a local Apple Development certificate, only if needed

A signing identity is the certificate **plus** the private key in this Mac’s login keychain. The private key must be generated here. Do not import a private key from another Mac, and do not revoke another machine’s certificate to make room.

First copy the local config and run the preflight. It tells you whether you still need to click **+**.

```bash
cp Config/Developer.xcconfig.example Config/Developer.xcconfig
# Set DEVELOPMENT_TEAM to the team ID shown in Xcode > Settings > Accounts.
cp Config/local_devices.env.example Config/local_devices.env
# Set WATCH_UDID to this Watch. Do not commit either file.
brew install xcodegen    # if needed
./scripts/check-signing-prereqs.sh
```

Interpret the result this way:

- If the script says the identity is OK, do not click **+** in Manage Certificates.
- If it says an identity is present but not trusted, install WWDR G3 (next section). Do not click **+**, and do not delete the certificate.
- If it says there is no identity on this Mac, open **Xcode > Settings > Accounts**, select that Apple ID and the same team, open **Manage Certificates…**, and use **+** to add **Apple Development**.

If **+** says “You already have a current Development certificate or a pending certificate request,” stop. That usually means a certificate already exists and the problem is trust or a missing intermediate, not a missing certificate. Do not revoke another Mac’s certificate.

**You confirm:** any Keychain access or Apple ID dialog while creating a certificate.

## 4. Install WWDR G3 when trust fails

Apple Development certificates are issued by the WWDR G3 intermediate. If this Mac only has an older, expired WWDR with the same common name, `security find-identity -v -p codesigning` stays empty even though Xcode shows the certificate in the keychain (a blank status, not “Not in Keychain”).

```bash
./scripts/check-signing-prereqs.sh --install-wwdr
./scripts/check-signing-prereqs.sh
```

The first command downloads [AppleWWDRCAG3.cer](https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer) and installs it into the login keychain only.

**You confirm:** the login keychain password or Allow prompt. That authorizes writing Apple’s official intermediate. It is **not** creating a new Apple Development certificate. Do not set trust to Always Trust.

This was confirmed on 2026-11-10 at 15:36 Asia/Shanghai: after that dialog, the identity became valid and a local signed package built successfully.

## 5. Enable Developer Mode and trust this Mac

1. On the Watch: **Settings > Privacy & Security > Developer Mode**, then restart when asked.
2. Bring the Watch close, wake it, and unlock it.
3. If the Watch or its paired iPhone asks to trust this computer, confirm it on the device.
4. Check that `xcrun devicectl list devices` can see this Watch.

**You confirm:** Developer Mode, the restart, and Trust This Computer.

Do not unpair the Watch or reset system Bluetooth to make the device appear.

## 6. Build the encrypted package

```bash
./scripts/ship-encrypted-hogp.sh
```

This builds the `standard128-encrypted` recipe (encrypted reads for the Report Map and input Report, plus encrypted notifications for the input Report) and writes `build/diagnostics/recovery-root/WatchHID-encrypted-hogp.zip`. That directory is gitignored.

`xcodebuild` may refresh the development provisioning profile for this Apple ID. The profile must still include this Watch. Use `python3 scripts/watchhid_scriptlib.py provision-info ./WatchHIDWatchApp.app` to check expiry and whether the configured Watch is included. Do not paste `security cms -D` output into chat or git.

**You confirm:** any Keychain access or codesign prompt on the first build.

A still-valid pre-signed zip can be installed without a local certificate, but that is not the default path once the project is on this Mac. Free profiles usually last about seven days; re-sign here with the same Apple ID.

## 7. Install onto the Watch

The product Watch app is watch-only (`WKWatchOnly`): it has no iOS companion and is not embedded in the optional iOS diagnostic target. Install the `WatchHIDWatchApp` scheme or `./scripts/install-signed-watch-app.sh`. A paired iPhone may still be needed for the developer tunnel or system Watch services; that is not the same as installing a companion app. Watch Connectivity log export to the iOS tool is not available.

The install script waits for a `connected` developer tunnel and matches only the UDID in `Config/local_devices.env`. It will not install onto a different Watch. A `connected` list entry is not sufficient by itself: after the tunnel is listed, the script also probes CoreDevice details and DDI services. On 2026-11-10, two installs on a home Mac failed with “Failed to allocate RSD device” after the list said `connected`; the same package installed once those probes succeeded. Signing was not changed. See [evidence/home-mini-neutral-picker-2026-11-10.md](evidence/home-mini-neutral-picker-2026-11-10.md).

```bash
./scripts/install-signed-watch-app.sh --check-ready   # probe only; does not install
./scripts/install-signed-watch-app.sh
```

If the tunnel is not `connected`, or the details/DDI probe is not ready, the script prints what to do and exits. Typically:

1. Bring the Watch close, wake and unlock it, and keep the screen on.
2. Bring the paired iPhone close, unlock it, and join the same Wi-Fi if you can. A USB cable is not required.
3. Run `--check-ready`, then the installer, when those checks pass. Do not treat a stale `connected` list line as install-ready.

A wireless install has succeeded with the iPhone nearby, unlocked, and on the same Wi-Fi, with no USB cable. That does not mean the iPhone is always required, and it does not prove install still works when no iPhone is nearby.

If `devicectl` shows `connected` but an older script reported the Watch state as `unknown`, update to a revision that matches `hardwareProperties.udid` as well as the CoreDevice `identifier`. Those two values are different.

**You confirm:** any Trust or install prompt on the Watch, and keeping the Watch and iPhone awake while the tunnel comes up.

## 8. Pair HOGP on this Mac

1. Unlock the Mac and move the pointer to a safe blank desktop.
2. Open WatchHID on the Watch and leave it in the foreground with the screen on. You should see status text. If the app is on the lock screen or in the background, the Mac often reads the system Apple Watch Device Information instead of WatchHID.
3. If macOS shows a Bluetooth passkey or pairing confirmation, complete it in the system dialog. That is part of setup. It is not unpairing the system Apple Watch, and it does not require a Bluetooth reset.
4. Short-drag on the pad, then light-tap.

Current source (`dc02abf` and later) arms the pad and sends mouse reports when at least one Report CCCD subscriber is present. Older packages required one hardcoded Mac central and could stay on `等待 Mac 系统订阅` (“waiting for the Mac system to subscribe”) even after this Mac had subscribed. Install a current package before judging a new Mac.

Then run:

```bash
./scripts/verify-hogp-mouse.sh
```

Success is both of these:

1. `NODE_OK`: one IOHID node has Manufacturer `WatchHID`, ModelNumber `Ultra2-R1`, and Generic Desktop mouse/pointer usage.
2. You see the pointer move.

A Bluetooth-connected Watch, a confirmed pairing prompt, or a connected developer tunnel is not enough. Do not reset the bond you just made.

On 2026-11-10, a second Mac completed pairing and encryption, then after the gate-fixed local package was installed, the operator confirmed pointer movement and `verify-hogp-mouse.sh` reported `NODE_OK`. Reconnect reliability and wireless iPhone isolation are still not fully proven. Details: [evidence/new-mac-hogp-2026-11-10.md](evidence/new-mac-hogp-2026-11-10.md).

## Human prompts the scripts cannot click for you

| When | What you see | What to do |
|---|---|---|
| `xcode-select` / first launch | Administrator password or license | Confirm in the system dialog |
| Xcode Accounts | Apple ID password and two-factor code | Enter them only in that official window |
| Manage Certificates, and only if preflight says there is no identity | Create an Apple Development certificate | Use **+**. If it says a current certificate already exists, stop |
| `check-signing-prereqs.sh --install-wwdr` | Login keychain password or Allow | Confirm. This writes WWDR G3, and does not create a Development certificate |
| First `ship-encrypted-hogp.sh` | Keychain access / codesign | Confirm in the official dialog |
| Watch / iPhone | Developer Mode, restart, Trust This Computer | Confirm on the device |
| Install while the tunnel is down, or after a connected list entry if RSD/DDI is not ready | No dialog; the script explains the steps | Wake and unlock the Watch, unlock the iPhone, same Wi-Fi, then `--check-ready` before installing |
| First HOGP use on this Mac | Bluetooth passkey or pairing confirmation | Confirm in the macOS system dialog. Do not reset Bluetooth |

## After setup

How to use the pad and dictation: [usage.md](usage.md). If something fails: [troubleshooting.md](troubleshooting.md).
