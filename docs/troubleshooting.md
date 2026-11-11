**English** | [简体中文](troubleshooting.zh-CN.md)

# Troubleshooting

Try the matching row first. Do not reset system Bluetooth or unpair the system Apple Watch to “fix” WatchHID.

| Symptom | Likely meaning | What to do |
|---|---|---|
| The Watch never becomes ready to advertise, or Watch Bluetooth permission controls are unavailable and say settings are shared with iPhone | Some Watch privacy settings can be managed on the paired iPhone, even though WatchHID has no companion iPhone app | On the paired iPhone, open the iPhone **Settings** app and go to **Settings > Privacy & Security > Bluetooth**. If WatchHID is listed, enable it, then return to WatchHID. Do not reset or unpair system Bluetooth, and do not reinstall the app for this. If WatchHID is not listed, inspect the current privacy state rather than resetting. Apple documents shared Watch/iPhone privacy management and the Settings > Privacy & Security > Bluetooth path; this iPhone Settings recovery has been confirmed when Watch controls were unavailable, but it is not a universal requirement for every setup. |
| Pointer does not move, but the Watch shows Ready | Ready only means the selected host subscribed | Pick the intended Device in Settings, tap Test or drag, and watch that machine. Confirm a pairing prompt if macOS shows one. Then use `./scripts/verify-hogp-mouse.sh` plus movement you see yourself. |
| The selected host is an iPhone, but that iPhone shows no pointer | Using an iPhone as a mouse/pointer host requires AssistiveTouch on that iPhone | On the target iPhone (the one that should show the pointer), enable **Settings > Accessibility > Touch > AssistiveTouch**. This is a system setting, not a WatchHID companion app, and it is separate from enabling WatchHID under **Settings > Privacy & Security > Bluetooth** on the paired iPhone. The `verify-hogp-mouse.sh` check applies to a Mac host. |
| `verify-hogp-mouse.sh` reports `NODE_OK` but you still see no movement | Identity is not a motion test | Watch the desktop while you drag. Another host may be the selected output. |
| Pointer only moves up and down after enabling the keyboard | A composite mouse+keyboard Report Map was used on a host that already bonded the baseline 4-byte mouse map | Turn English keyboard HID off and restore the baseline mouse map. Do not use a composite Report Map on that bond. The current app keeps the keyboard on a separate service. |
| Keyboard Setup Assistant appears | macOS saw a new keyboard HID | Close the assistant. Do not complete identification, and do not use another keyboard to identify WatchHID. There is no official way to guarantee it will not appear. |
| The system input sheet opens a keyboard or Scribble instead of recording | The system chose the initial input method | Switch to the microphone in that system sheet, then dictate and tap Done. This is expected; the public API does not force dictation-first. |
| Dictation finishes but nothing is typed on the Mac | Keyboard HID may be off, the Mac field may not be focused, or the result was empty, cancelled, or non-ASCII | Turn English keyboard HID on, focus a typable field, and accept typable English with the system Done control. An empty or cancelled sheet does not type. |
| Install fails with “Failed to allocate RSD device” or a CoreDevice / RemotePairing tunnel timeout | A `connected` list entry is not a sufficient install gate | Keep the Watch close, awake, unlocked, and screen-on. Run `./scripts/install-signed-watch-app.sh` only (it has its own readiness probe). Optional standalone diagnosis: `./scripts/install-signed-watch-app.sh --check-ready` when you are **not** about to install. Do not run `--check-ready` and install back-to-back. Do not retry in a tight loop. Do not revoke certificates. |
| Install cannot find this Watch | The script matches only the `WATCH_UDID` in `Config/local_devices.env` | Confirm you filled the gitignored env file for this Watch. Do not guess another device from a list. |
| A new Mac never gets a mouse node | Encrypted HOGP bonds are not transferable | Create a new bond on this Mac. Do not copy Bluetooth preferences or keychain items from another Mac. |
| Input stops after the Watch sleeps or shows the clock | The app must be in the foreground with the screen on | Open WatchHID again and start a new gesture. Background input is not supported. |
| The Watch app disappears after you uninstall an iPhone WatchHID app | An older iOS product may still embed the same Watch bundle as a companion app. Removing that iPhone app can take the Watch app with it. The current watch-only package does not require a companion iPhone app. | Install the current watch-only Watch app directly. It is marked watch-only, has no companion bundle identifier, and has been confirmed to run with no iPhone WatchHID app installed. Do not treat a leftover embedded-Watch iOS product as the current packaging. |

## Commands

```bash
./scripts/check-signing-prereqs.sh
./scripts/install-signed-watch-app.sh
./scripts/verify-hogp-mouse.sh
```

`--check-ready` is only for a probe without installing:

```bash
./scripts/install-signed-watch-app.sh --check-ready
```
