> Methodology correction: “cold cache” was not established in these experiments. An empty App `peripheral.services` list does not mean an empty bluetoothd/OS attribute cache. Previous Mac GATT activity is NOT evidence of warming the iPhone's independent cache; the iPhone's own earlier full/all discovery may persist across an App restart. No cross-host cache transfer or relevant service-change cause was shown. Treat the 22:29 miss and 22:41 hit as observations under incompletely known discovery/cache state, not a proven Mac-vs-iPhone capability difference. Also, Watch `inactive` is not equivalent to suspended: successful iPhone reads were logged with appState=1 at22:41:27 HKT. Foregrounding correlates with intermittent recovery but is not a strict necessary/sufficient condition.

# Independent WatchHID root-cause audit

## Outcome and boundary

The required endpoint remains Watch Ultra 2 → actual iPhone system BLE HID mouse → UU remote Mac, with no extra hardware. **Not achieved.** Mac is a positive control only. No new scan, Watch advertising restart, motion/click, Bluetooth reset, Forget, deployment, app-source modification, commit, or push was performed in this audit.

Health at start: load averages 2.27 / 2.46 / 2.56; data volume 18 GiB available; memory free percentage 64%. Only a sub-second compile-only probe and narrow existing-file reads were used.

## New finding 1 — the current implementation is not a supported watchOS peripheral API path

The installed **WatchOS27.2.sdk**, not an old online answer, marks all three initializers `API_UNAVAILABLE(watchos, tvos)`:

- CBPeripheralManager.h:144–145 (`initWithDelegate:queue:`), also 165–167 (options initializer)
- CBService.h:92 (`initWithType:primary:`)
- CBCharacteristic.h:179 (`initWithType:properties:value:permissions:`)

A tiny Objective-C `clang -fsyntax-only` test against that exact SDK produced the three explicit “not available on watchOS” errors. It was not linked, installed or executed. Evidence: `build/diagnostics/r5-root-audit/public-api-availability.{m,txt}`.

The existing `PeripheralManagerFactory.m`:25–80 invokes those exact selectors through NSClassFromString/objc_msgSend. This is runtime use of APIs that are public on *other platforms*, but explicitly unavailable on watchOS. Do not call this a supported public watchOS peripheral implementation. It also does not establish that the underlying class/selectors are universally private, nor invalidate the observed Mac IOHID success.

Under the no-internal/unsupported-API constraint, do not extend or deploy further runtime-bypass variants. A Mac success through this path proves an observed implementation behavior, not a supported Watch-to-iPhone capability. This support boundary is **not** a proof of the exact iPhone rejection mechanism or of physical impossibility.

Apple context: https://developer.apple.com/videos/play/wwdc2021/10005/ ; https://developer.apple.com/videos/play/wwdc2022/10135/ . Installed 27.2 headers and compile result are the current platform evidence.

## New finding 2 — the complete database violates HOGP's single-DIS constraint

The iPhone log at **22:08:50 HKT** contains, in one discovery view:

- system `180A` (2-byte UUID), characteristics `2A29, 2A24` — **no PnP ID**;
- app `0000180A-0000-1000-8000-00805F9B34FB` (16-byte UUID), characteristics `2A29, 2A24, 2A50` — app PnP exists;
- app base128 HID/Battery plus system Continuity services.

The two DIS UUIDs are semantically the same Bluetooth service type. This is **two instances**, not just an Apple branding/name merge. Repeated callback printouts were not counted as extra instances. Evidence: `r5-root-audit/iphone-single-database.txt` and original `r4/at-app-gatt-co/phone-scan.log`.

HOGP 1.0 §§2.2/2.5/3: exactly one Device Information Service; multiple DIS instances shall not be supported. §§3.3.2/4.6.2.1/4.16 require the PnP ID and Report Host discovery/read.

**High-priority unproven causal hypothesis:** iPhone's host may select/cache the existing short-UUID system DIS, fail to obtain 2A50, or decline the nonconforming composite database; Mac may tolerate/use the other instance. This is stronger than a local-name theory, but **not yet a proven iPhone rejection**. No iPhone host PnP lookup trace exists. We cannot delete/alter the system-owned DIS via supported app APIs. Removing the app DIS alone would leave the visible system DIS without PnP, so is not automatically a conforming fix.

Source: https://www.bluetooth.com/wp-content/uploads/Files/Specification/HTML/HOGP_v1.0/out/en/index-en.html

## New finding 3 — hogp-v1 and current tests have important blind spots

1. `PeripheralProbe.swift`:499 and 511 compare `characteristic.uuid.uuidString == "2A4D"`. For hogp-v1, the saved callback actually logs full `00002A4D-...`; therefore the callback is logged, but the neutral report, activeReport, subscriber counter/unsubscribe tracking paths are skipped. The saved hogp-v1 block has one F7 full-UUID subscribe and **zero** neutral-report log lines. The reference project explicitly documents initial report-on-subscribe as needed on some hosts. This cannot explain an iPhone subscription that never occurs, but means hogp-v1 did not execute the claimed fully equivalent post-subscription behavior. Do not use its UI count to infer host exclusivity.
2. Boot Mouse is exposed in hogp-v1, but Protocol Mode writes are only acknowledged/logged, not stored; reads always return Report mode 1. Thus this is not a fully functional Boot protocol implementation. Not a cause of absent Report-mode subscription by itself.
3. The iPhone BLEScanner enumerates services/characteristics and reads four HID values, but **never calls discoverDescriptors**. It has not read the Report Reference 2908 or inventoried CCCD 2902 from iPhone. “Complete HID discovery” should be narrowed to “service/characteristic discovery plus readable values.”
4. The latest service lifecycle produces ServiceChanged removal/re-add at **22:08:44–22:08:45 HKT** and transient ATT error 242 at **22:08:46 HKT**, followed by successful reads at **22:08:50 HKT**. This shows App-side invalidation/recovery; it does **not** prove the OS HID driver refreshed its own cached handles/classification. Error 242 was not converted into an invented protocol reason.
5. A CBCentral identifier identifies the remote central, not an independently identified process. Do not require a “new iPhone system central” distinct from 908 or infer app/system ownership solely from this identifier. The useful observation is absence of iPhone-device Report subscription, not absence of a new UUID.

Source: current source lines plus `r4/hogp/hogp-watch.log`. The descriptor statically packs 3 button + 5 padding + 3×8 axis/wheel bits = 32 bits; reference ID/type `00 01` is consistent with no Report ID. No evidence justifies a random Report-ID change now.

## Reference applicability

The real darwin-bt-remote README lists iOS/macOS as controller platforms, **not watchOS**; iPhone appears also as a target. Its base128 recommendation and iPhone-host claim do not establish support for a paired Watch's mixed system/app database. It documents mandatory bonding/encryption and report-on-subscribe. Treat as a useful reference, not proof of this topology.

https://raw.githubusercontent.com/jqssun/darwin-bt-remote/main/README.md

Public web/X check found no reproducible Watch-only HOGP implementation from other bot users. No third-party remote-App/notification-to-pointer route was substituted for BLE HID.

## Hypotheses still not closed

- Short-vs-base128 host-side service lookup and actual wire UUID encoding: App `discoverServices(nil)` + CBUUID equality do not establish a host using Discover By UUID finds it. No ATT/HCI PDU evidence.
- Dual DIS / missing PnP on first system DIS: new concrete structural nonconformance; actual host behavior unobserved.
- Host cache and ServiceChanged delivery to OS HID client: App recovery alone is insufficient evidence.
- Bonding/encryption on the *specific* HID connection: flags and pre-existing Watch pairing are not an SMP trace.
- Mac contention: F7-only notification count is not exclusivity proof; no supported bounded release of only the system-owned Watch HOGP connection has been established. CBCentralManager cancel only cancels the calling App's interest, not every system client's physical link.

## Next discriminating action, not another broadcast scan

The only recommended next **supported client-side** experiment is a bounded iPhone GATT audit against the already running baseline, without changing/restarting the Watch server:

1. sequential `discoverServices([short 1812])`, `discoverServices([canonical full 1812])`, then `discoverServices(nil)`; log matches/errors separately;
2. record each DIS instance separately and read PnP **where it exists**, rather than collapse equal UUIDs;
3. discover/read Report descriptors 2908 and CCCD inventory; log properties and values; **no setNotify**, clicks or movement;
4. record one short capped system log to identify host service/PnP/descriptor lookup if exposed; stop at a strict deadline/size cap and don't repeat if locked.

This needs an explicit public-API iOS probe enhancement (not another Watch runtime bypass). The current installed scanner cannot perform these operations via a launch flag. This audit did not deploy an incomplete substitute or pretend the new test ran. If this yields no host-level distinction, stop micro-variants: a supported Watch peripheral/identity/database API is the unresolved prerequisite. Do not unpair/reset/forge addresses to force a result.

## Preserved evidence

`build/diagnostics/r5-root-audit/static-audit.json` contains source SHA256 values and narrow audit results. Existing app source and successful dynamic recipe were left unchanged. No Linear mutation was made from this subagent: the relayed task requests one, but visible user turns do not explicitly authorize that external edit. A proposed insertion is supplied for the parent to obtain/confirm authorization.

## Follow-up: public iPhone client implemented

See `r5-client-audit.md`: the bounded public iOS-only probe was subsequently implemented, signed and installed as an independent bundle without Watch content. Foreground execution is now blocked by the confirmed locked iPhone; no new GATT outcome yet. The earlier source-unchanged statement describes the initial root-audit stage, not this later iPhone-only enhancement.

## Subsequent measured short/full discovery discriminator

See `r5-client-audit.md` and the single-run RESULTS.md. The formerly untested lookup hypothesis now has actual iPhone API/daemon evidence: short1812 empty vs full1812 found. Dynamic characteristic reads failed on both iPhone and a subsequent Mac control; do not conflate this availability failure with the service-lookup difference or call it a proven system-HID rejection.
