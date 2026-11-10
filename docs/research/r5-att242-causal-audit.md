# ATT242 causal audit and tonight's Mac-only handoff

All human-readable times in this report are Asia/Hong_Kong (HKT, UTC+8).
This round used existing artifacts plus one bounded Watch process/display snapshot. No new iPhone window, BLE client, scan, subscribe, write, input, process activation, kill, installation, or reset.

## Result
No significant iPhone system-HID breakthrough. 242 is still not localized to a single root cause. A real observability defect was repaired locally: ATT response evidence previously depended on MainActor, with timestamp and appState sampled only when UI logging eventually ran. **Missing old Watch logs do not prove the delegate was not called.** New code is built but not deployed; therefore do not reinterpret historical evidence as if the new trace had been installed.

## Reproducible 22:41 vs 22:48 comparison
Sources:
- `build/diagnostics/r5-client/run-20261109-224126/Documents/watchhid-gatt-audit-990F6E38-2E45-479D-B916-2EFF985CD92E.log`
- `build/diagnostics/r5-client/run-20261109-224826/Documents/watchhid-gatt-audit-5BD4DF50-D166-4FF7-8BF4-3C2E52350A07.log`
- `build/diagnostics/r5-client/iphone-only-20261109-224821/watch.log`
- Corresponding `iphone-capped.log`; targeted line-numbered excerpts in `build/diagnostics/r5-live-audit/*-read-excerpts.txt`.

| Dimension | 22:41:27 | 22:48:27 |
|---|---|---|
| Client inventory duration | 0.731s | 0.750s |
| UUID/known daemon view | short/full/all resolve existing full HID | same; not cold cache |
| ReportMap / Report / HIDInfo / App DIS | clean values, error=nil | old-looking values **plus242**, not success |
| Protocol Mode | nil+242 | nil+242 |
| Watch ATT legacy log | six iPhone-central read/result=0 rows (Map, Report, HIDInfo, three DIS) | no matching recorded rows |
| Last logged active | 22:41:20.704 | 22:47:12.137 |
| Last logged inactive | 22:41:25.915 | 22:47:17.295 |
| Meaning | reads succeeded while inactive; inactive != suspended | >~69s after last inactive; actual execution/scene during reads unknown |
| Prior Mac read | Map success at22:41:25.499 | no new Mac active GATT |
| Service mutation during audit | no App invalidation | no App invalidation |

Protocol Mode already failed while six other reads succeeded, so first-read ordering is NOT an established fix. Earlier 22:08:14/22:08:50 records include iPhone Protocol Mode result=0; it is not proven permanently forbidden either. Mac previously also returned242 when dynamic values were unavailable, so failure is not established iPhone-only. The nearby Mac success in 22:41 is confounded with recent Watch activity; Mac cache-warming is unproven.

### Activation and process evidence
22:48 Watch `devicectl --activate` returned PID821, `activatedWhenStarted=true`, `terminateExistingInstances=false`. There was no new logged scene-active transition then. That result is a successful command/launch request, not proof of current foreground execution. This round's supported process snapshot still returned PID821; display snapshot says `backlight is on and inactive`. These current snapshots establish process presence/display state only—not historical suspension, ATT queue health, or App foreground state. Snapshot files contain their original command timestamps.

## Causal code audit
- `PeripheralProbe` is a MainActor singleton held by WatchApp's StateObject and static `shared`. `dynamicPeripheral` strongly holds the manager; `pendingServiceObjects` holds the service graph until stop. Characteristics are attached via setters. No obvious unretained-delegate/manager bug explains this pair.
- Manager receives a named serial queue. `didReceiveRead` is nonisolated and computes/replies synchronously before the MainActor Task (`PeripheralProbe.swift` around415–474). Therefore the old UI hop is NOT on the response critical path. Queue supplied to CoreBluetooth is not observed to vanish; no evidence justifies changing its ownership model or queue/factory.
- Last logged manager creation/add/advertising was22:11:41 (manager0x1013c95e0), not at22:48. No intervening logged stop/rebuild. Start guard prevents a normal duplicate start. An immediate state poll and later didUpdateState could theoretically both build if already poweredOn, and stale delegate/state callbacks after stop are a general race risk; neither was observed in these two windows. Do not change service layout based on that speculation.
- `WHRespondToRequest` directly calls the existing selector. No catch/time measurement previously distinguished entry/return; there is no evidence of a thrown exception. This round did NOT modify/extend the factory or unavailable API use.
- LogStore synchronously updates Published entries and opens/seeks/writes/closes on MainActor. ATT records were enqueued onto MainActor after reply, using a new timestamp and WK applicationState at logging time. Thus missing/delayed logging and state attribution were real observation gaps; they are not established sources of242.
- WatchConnectivity activation, command acceptance, and background completion run through MainActor. Matrix sleeps yield; normal finishBackgroundDelivery is bounded to~5s unless a matrix task is active. There are no logged WC/matrix commands in the22:41/22:48 comparison. Earlier CAROUSEL watchdog reports and cold WC background failure remain relevant history, not proof of current main-thread saturation. No new stack sample from the actual failure second exists.
- Background delegate completes snapshots normally and delays WC task completion only for its bounded delivery/matrix. No supported runtime extension/category was added. SDK unavailable means no supported stable peripheral-role guarantee on watchOS; it does not erase observed Mac HID input or prove physical impossibility.

## Minimal local observation repair (not deployed)
Changed only `Apps/Watch/LogStore.swift` and `Apps/Watch/PeripheralProbe.swift` in this round:
1. Unified-log `ATT_ENTER` on callback entry (id, UUID, central, main-thread flag).
2. `ATT_RESPOND_RETURN` after existing response call returns.
3. Independent bounded131072-byte callback JSONL, written after response return, serialized with NSLock; records callback epoch/uptime, response uptime/latency, manager, PID, central, UUID, offset, bytes, result.
4. Legacy UI row now includes original callbackTime and explicitly names state `appStateAtLog`.

Disk work happens AFTER response, not before. It may delay subsequent callbacks slightly; this is instrumentation, not a claimed availability fix. Cap/file failures are reported and mean missing evidence is UNKNOWN. Entry is unified-log evidence; JSONL records only returned response submissions, not radio delivery. Independent entry exists if response blocks, but requires unified-log capture to observe that case.

Evidence/verification:
- This-round before snapshots/hashes and exact `callback-observation.patch` under `build/diagnostics/r5-live-audit/`.
- Runtime factory `.m/.h` and WatchApp lifecycle hash unchanged (`untouched-factory-lifecycle.json`). Existing source/diffs preserved; no commit/push.
- Host callback test completed before its blocked MainActor timed out; `host-check-result.txt`. It checks logging independence, NOT Watch scheduling.
- Two-job unsigned generic-watchOS build succeeded (`watch-build.log`, line576). Shell wrapper subsequently hit zsh's reserved `status` variable; xcodebuild itself already finished successfully. No signed build/install/kill/relaunch.

## Automatic stage gate
`scripts/assess_live_read.py` is a read-only file evaluator; `scripts/test_assess_live_read.py` has12 passing tests including historical fixtures. Requires clean exact Map + HIDInfo, matching iPhone-central independent callback rows with correct bytes/result/offset, no service invalidation, and <=2s freshness for `ready_now=true`. Wrong values, data+error, wrong service/central, stale/future data, or missing callbacks fail closed. Legacy records can mark a past window corroborated but NEVER ready_now.
-22:41 fixture: corroborated read window=true, ready_now=false.
-22:48 fixture: corroborated read window=false, ready_now=false.

This is an auditable evidence gate, not yet a deployed real-time orchestrator. Readiness is a short lease, never a promise of future background execution. A usable75s orchestration must consume the event in-process/streamed, not wait48s collecting syslog before evaluating.

### Next informative experiment (not another UUID/order loop)
After a justified next normal deployment (ideally combined with tonight's Mac touchpad UI), run ONE client-only, known-peer observation session, preserving current recipe. Capture callback unified logs + JSONL and normal scene events; no repeated activation/reinstall. In one75s budget: first<=8s perform minimal Map+HIDInfo liveness check, then at most one scheduled sample around10s and one around60s if useful; stop on first loss and preserve evidence. No Protocol-first variation, no discovery matrix, no automatic retry/reset.
- No ATT_ENTER + system shows executing app: failure is before delegate delivery (exact layer still needs system evidence).
- ATT_ENTER but no RESPOND_RETURN: response handler/exception/block boundary.
- RESPOND_RETURN success, client242: response submission vs server/transport handling boundary.
- Callback evidence immediate but UI row delayed: MainActor/logging delay demonstrated, not background nonexecution.
- No callback + no execution evidence: unknown, NOT proved suspension.
For tonight this experiment is DEFERRED; do not request phoneUSB/unlock. Mac-specific client/system evidence can be used for the same logging experiment after UI is ready, but this evaluator's current input format/central is specifically the existing iPhone audit log.

## Tonight: smallest useful Mac Bluetooth mouse, no phone USB
Historical Mac real IOHID input and pointer movement are preserved, but sustained usability is unproven. Current UI offers only X+20/click diagnostic buttons; it is NOT full motion control.

Proposed minimal local feature for parent to approve/continue:
- Explicitly enabled finger-drag touchpad on Watch; relative dx/dy from finger deltas, not wrist/IMU control. Keep existing dynamic HID recipe and4-byte reports.
- Bounded rate(~30Hz), per-report signed-byte clamps, fractional accumulation; no send on startup/appearance. Subscriber + active scene + user-enabled + finger-down gate. Release/disarm on scene loss, unsubscribe, or touch end; separate explicit left-click control, not inferred taps while scrolling.
- Separate diagnostic controls from the touch surface. No fake workout/extended runtime category, safety/network changes, re-pairing or forced input capture. Observe IOHID path; do not count App connection/subscription as system success.
- One combined signed build/deploy only when UI is implemented/verified. Existing app may use WC for logs but BLE reporting does not await WC activation; no phoneUSB required for the actual Mac HID path. No claim of guaranteed always-on/screen-off operation.
- One consolidated owner action AFTER deployment: open WatchHID normally, choose Mac touchpad mode/enable, and perform a short warned drag over a safe Mac area. No automated click/move before that. Parent should ask only if drag-vs-wrist semantics remain genuinely ambiguous.

Actual blocker this round: no historical stack/scheduler/delegate-entry trace at22:48, and new trace not deployed. There is no new iPhone-system-HID acceptance evidence. This does not require Z to keep screens awake; continue reversible Mac UI development before asking for one consolidated action.

## Exact paragraph for parent's Linear update (do not publish from executor)
本轮242因果审计未取得iPhone系统HID突破。22:41:27在Watch inactive时六项动态读有成功委托日志；22:48:27同一已知HID布局动态读带242，激活命令成功但无同窗active/ATT记录，不能据此认定暂停或未调用委托。审计确认旧ATT日志经MainActor且时间/状态晚采样，已最小本地增加独立callback entry/response-return与有界JSONL，Watch无签名构建及主线程阻塞下日志独立性检查通过，未部署；未改runtime工厂/服务配方。自动证据闸门及12项测试通过，data+error/陈旧/缺回调均关闸，尚非已部署实时编排。今晚按Z指示转Mac直接BLE鼠标：保留历史IOHID真实输入成果，准备显式启用的手表手指拖动触控板、限速/限幅及失活停发，不依赖手机USB，不再催手机解锁；完成本地验证后集中一次签名部署/正常打开与安全拖动验证。
