# Docs

Start here:

| Doc | Topic |
|---|---|
| [setup.md](setup.md) | New Mac and any Apple Watch: Xcode, signing, WWDR G3, install, and first HOGP bond |
| [usage.md](usage.md) | Touchpad, clicks, and dictation after the app is installed |
| [troubleshooting.md](troubleshooting.md) | Failure modes, and what not to do |
| [../.cursor/skills/watchhid-new-mac-hogp/SKILL.md](../.cursor/skills/watchhid-new-mac-hogp/SKILL.md) | Short reusable procedure for the same path |

Evidence and deeper notes:

| Doc | Topic |
|---|---|
| [evidence/new-mac-hogp-2026-11-10.md](evidence/new-mac-hogp-2026-11-10.md) | Confirmed events on a second Mac on 2026-11-10 (Asia/Shanghai) |
| [evidence/home-mini-neutral-picker-2026-11-10.md](evidence/home-mini-neutral-picker-2026-11-10.md) | Home the development Mac, 2026-11-10: output picker, RSD install readiness, operator acceptance, Keyboard Setup Assistant limits |
| [evidence/mini-ksa-ab-baseline-2026-11-10.md](evidence/mini-ksa-ab-baseline-2026-11-10.md) | Home the development Mac, 2026-11-10: KSA A/B baseline, Logitech-targeted reopen, no Continue |
| [SIMULATOR-CHECKS.md](SIMULATOR-CHECKS.md) | Simulator UI and text-input callbacks; not BLE or speech |
| [large-pad-dictation-en.md](large-pad-dictation-en.md) | Feature-branch intent for the large pad and optional English HID |
| [research/](research/) | Earlier experiment notes and audits |

Do not commit raw `build/diagnostics/**` logs, screenshots, crash files, sysdiagnose archives, or provisioning profiles. Working device IDs live only in gitignored `Config/local_devices.env`.
