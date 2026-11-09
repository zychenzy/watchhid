> Methodology correction: “cold cache” was not established in these experiments. An empty App `peripheral.services` list does not mean an empty bluetoothd/OS attribute cache. Previous Mac GATT activity is NOT evidence of warming the iPhone's independent cache; the iPhone's own earlier full/all discovery may persist across an App restart. No cross-host cache transfer or relevant service-change cause was shown. Treat the 22:29 miss and 22:41 hit as observations under incompletely known discovery/cache state, not a proven Mac-vs-iPhone capability difference. Also, Watch `inactive` is not equivalent to suspended: successful iPhone reads were logged with appState=1 at22:41:27 HKT. Foregrounding correlates with intermittent recovery but is not a strict necessary/sufficient condition.

# Bounded public iPhone client audit — implementation and deployment

## Scope

Only `Apps/iOS/BLEScanner.swift` was changed in app source. Its existing behavior is retained unless `--gatt-audit` is passed. A dedicated `BoundedHIDClientAudit` uses documented CoreBluetooth client APIs only. It does not scan, setNotifyValue, writeValue, send WatchConnectivity messages, or create Watch peripheral objects.

To avoid an update to the existing companion bundle possibly syncing Watch content, the audit is built as an **independent iPhone-only app** `com.zy.watchhid.gattaudit`, with only BLEScanner.swift and a minimal SwiftUI entrypoint. It has no Watch target, embedded Watch app, or WatchConnectivity session. Existing `com.zy.watchhid` and Watch installation were not replaced.

Build specification and standalone entrypoint are reproducible at `build/diagnostics/r5-client/{project.yml,AuditApp.swift}`. The prior cumulative BLEScanner contents are backed up at `build/diagnostics/r5-client/BLEScanner.before.swift`. Other agents' pending changes were not reverted. Original Watch probe/factory and Shared/HIDDescriptors SHA256 values remain unchanged versus the independent root audit.

## Implementation

- Retrieve only the explicitly supplied known peripheral UUID. No scan fallback.
- Sequential service-discovery requests: short `1812`, canonical full `00001812-0000-1000-8000-00805F9B34FB`, then all services.
- Log request UUID representation, preexisting cached services, returned cache view, service-object identity, UUID data length/hex, primary state and characteristic properties.
- Process each HID/DIS service object separately. Log presence/absence of 2A50 per DIS and read all readable DIS/HID characteristics.
- Discover descriptors for each HID characteristic and read only 2908/2902 values where exposed. Never write CCCD or subscribe.
- 5-second individual-operation timeout; 45-second total deadline; 128KiB app-log cap. ServiceChanged during the run aborts rather than silently restarting. Completion cancels only this app's connection interest, with no claim of physical-link disconnection.
- UUID-filter callbacks expose CoreBluetooth's cumulative cached service view, **not raw filtered ATT responses**. Previously cached services are logged so results cannot be falsely called wire-format proof.
- CBCentral UUID is a remote-device identity, not a distinction between same-phone App/system processes. The earlier `iphone-vs-mac-hid.md` and joint-window ANALYSIS wording was corrected accordingly.

## Actual results

- Initial health: load 2.15/2.37/2.49, available disk 18GiB, free-memory percentage 64%.
- First single-target build found two optional CBDescriptor.characteristic handling errors; corrected. Delegate conformance uses @preconcurrency with the explicitly main-queue CoreBluetooth manager.
- Final **single-target signed build succeeded at 22:21:03 HKT**; no Watch target was built. Only existing unrelated `var item` and AppIntents metadata warnings remain. `codesign --verify --deep --strict` passed.
- Independent iPhone app **installed successfully at 22:21:30 HKT** using the existing free signing account. No Watch installation/relaunch command was issued.
- At **22:21:24 HKT**, the documented `devicectl device info lockState` returned `passcodeRequired=true`. This is the actual physical-action blocker. No launch was attempted against the known locked phone, no repeated unlock requests, no capture started, and **no new GATT result is claimed**.
- Runner command-argument handling was unit-tested with a subprocess stub: timeout remains before the app `--` argument delimiter. Python syntax and absence of write/notify/scan calls in the dedicated audit class were checked.

Evidence: `build/diagnostics/r5-client/build-fixed.log`, `phone-lock.json`, signed app under `DerivedData/Build/Products/Debug-iphoneos/WatchHIDClientAudit.app`; install command result was recorded in terminal log `/Users/czy/terminals/241137.txt`.

## Ready next action

Z needs to unlock iPhone and keep it awake. As this is a new independent bundle, its first Bluetooth use may show an OS permission prompt; Z must approve it personally if they want the test to run. This is not an instruction to change security settings or reset a bond.

Then run exactly once:

```
python3 ~/projects/watchhid/scripts/run_iphone_gatt_audit.py
```

The script checks lock state once and stops without launching if locked. It does not build, install, or manipulate the Watch. When unlocked it launches only the installed audit app, captures only bluetoothd/audit process syslog up to 48 seconds or 2MiB, terminates that logger, and copies the audit app's Documents via devicectl. App-side read audit remains bounded independently. A missing known target or denied permission is a no-retry stop, not permission to scan or alter pairing.

Interpretation targets: actual short/full discovery behavior at the API/cache layer, two DIS objects and PnP availability, iPhone visibility of Report Reference and CCCD. These are not system HOGP success and cannot alone establish why the system HID host did not subscribe.

## Actual single audit executed

One iPhone run started at 22:29:50 HKT and finished its read sequence at 22:29:53 HKT (3.259 s, under the 45 s maximum). Permission was personally granted. System log 48 s / 1,201,883 bytes; app log 17,961 bytes. No retry or Watch recipe change.

**New measured discriminator:** short1812 discovery returned empty with no error from an initially empty App cache; full1812 immediately returned one service. bluetoothd independently logged “No primary services with UUID 0x1812 found”, followed by canonical-full service discovery. This is API/daemon evidence, not raw ATT/HCI evidence or a proven system-HID binding cause.

Two distinct DIS instances were measured: system short180A lacks PnP and its Apple Inc./Watch7,5 reads succeed; App full180A contains PnP but its value read fails. Report descriptors read successfully: 2908=0001, 2902=0. Protocol Mode/Control Point additionally expose extended properties and2900 in the remote view; origin/causality unproven.

Important: **7 of9 characteristic reads failed with242** (all four dynamic HID and three App DIS values). The App completed inventory, not successful reads. Existing Watch process remained present, but its log had no new reads and last recorded background state at22:11 HKT. A separate direct-known-peer Mac read control at22:33:16 HKT also returned242 for Report Map, without scan/notify/write or Watch relaunch. The current dynamic-value failure therefore is not shown to be an iPhone-only rejection; suspension/server availability is plausible, not proven.

Full evidence and conclusions: `build/diagnostics/r5-client/run-20261109-222949/RESULTS.md`. Next physical precondition: existing WatchHID foreground/responding, without republishing the recipe; do not silently repeat the same iPhone audit. Short/full host-discovery mismatch remains the strongest concrete lookup hypothesis, while actual system-HID lookup/caching behavior is still unobserved.

## Dynamic recovery + Mac short/full contrast

See `build/diagnostics/r5-client/RECOVERY-AND-SHORTFULL.md`. Mac Report Map recovered once at 22:40:17 HKT with Watch ATT proof while scene active; fails again within seconds when inactive. Mac short1812 discovery finds HID (unlike prior iPhone empty short discovery). Phone still locked for re-audit.

## Recovered-window iPhone audit 22:41

See `build/diagnostics/r5-client/run-20261109-224126/RESULTS.md`. Mac dynamic read recovered; iPhone short1812 found HID in warm window (daemon already had full HID DB—may be cache). Cold 22:29 short-miss still stands. Dual DIS + live App DIS/PnP reads confirmed. CCCD=0. Not system HID success.

## Recovered-window iPhone audit 22:41

See `build/diagnostics/r5-client/run-20261109-224126/RESULTS.md`. Mac dynamic read recovered; iPhone short1812 found HID in warm window (daemon already had full HID DB—may be cache). Cold 22:29 short-miss still stands. Dual DIS + live App DIS/PnP reads confirmed. CCCD=0. Not system HID success.

## iPhone-only attempt and scene review

See `build/diagnostics/r5-client/IPHONE-ONLY-PREP-AND-METHOD.md`: one activation succeeded22:43:58 HKT but phone lock blocked GATT. Reproducible no-Mac-active-GATT wrapper prepared and blocked paths tested. No cleared-cache or cross-host warming claim. SDK27.2 explicitly marks old frontmost-timeout extension unsupported; no fake runtime categories or Watch deployment used.

## iPhone-only run 22:48 (no Mac active GATT)

See `build/diagnostics/r5-client/iphone-only-20261109-224821/RESULTS.md`. Short1812 resolved known full HID; dual DIS remains; HID/App-DIS values returned with 242 and Watch logged **no** ATT reads that second—do not treat as live. Cache still unknown. Stop identical discovery loops; next needs Watch-proven ATT.

## ATT242 causal audit / Mac-only handoff
See `docs/r5-att242-causal-audit.md`. Correction: historical absence of MainActor-delivered ATT log rows does not prove delegate non-invocation. Callback replies already occur before that hop; the local observation fix is not an availability/root-cause fix and is not deployed. No new phone window. Tonight shifts to explicit Watch finger-drag Mac BLE HID usability, not an iPhone acceptance claim.

## Mac BLE touchpad MVP installed
See `docs/mac-touchpad-mvp.md`: new UI visually confirmed disabled with Mac subscriber; exact-descriptor system BLE IOHID node present. No automated movement/click, human test pending.24 logic tests+12 evidence-gate tests passed. Phone USB not used/required for actual HID input.
