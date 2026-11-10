# Docs index

Human-readable experiment notes only. **Do not commit** raw `build/diagnostics/**` logs, screenshots, crash `.ips`, sysdiagnose archives, or embedded provisioning profiles.

| Doc | Topic |
|---|---|
| [SETUP.zh-CN.md](SETUP.zh-CN.md) | 新 Mac：官方 Xcode、何时需要本机签名；开发通道与蓝牙的区别；无现成 HOGP 绑定时用 ship-encrypted-hogp.sh 与 install-signed-watch-app.sh；配对/加密已实证、身份与指针仍待验证 |
| [new-mac-hogp-2026-11-10.zh-CN.md](new-mac-hogp-2026-11-10.zh-CN.md) | 2026-11-10 新 Mac 加密 HOGP 路径的证据/推断分界与源码门闩说明 |
| [watchhid-new-mac-hogp skill](../.cursor/skills/watchhid-new-mac-hogp/SKILL.md) | 把新 Mac / 无加密绑定这条路径写成可复用步骤，供后续接手直接执行 |
| [QUICKSTART.zh-CN.md](QUICKSTART.zh-CN.md) | 回来后真机试用与听写边界 |
| [RETURN-CHECKLIST.zh-CN.md](RETURN-CHECKLIST.zh-CN.md) | 出门后回来的最短验收步骤、证据边界和失败时不要做什么 |
| [mac-touchpad-mvp.md](mac-touchpad-mvp.md) | Mac BLE touchpad MVP install + owner-acceptance boundary |
| [r5-att242-causal-audit.md](r5-att242-causal-audit.md) | ATT242 causal audit; callback observation vs availability |
| [r5-client-audit.md](r5-client-audit.md) | iPhone client audit notes |
| [r5-independent-root-audit.md](r5-independent-root-audit.md) | SDK unavailable / dual DIS / methodology |
| [r4-system-discovery.md](r4-system-discovery.md) | System discovery / matrix history |
| [r2-r3-results.md](r2-r3-results.md) | Earlier R2/R3 results |
| [r1-matrix-results.md](r1-matrix-results.md) / [r1-local-repair.md](r1-local-repair.md) | R1 matrix / local repair |
| [iphone-vs-mac-hid.md](iphone-vs-mac-hid.md) | iPhone vs Mac HID contrast |
| [hogp-ios-audit.md](hogp-ios-audit.md) | HOGP layout notes |
| [diag-channels-inventory.md](diag-channels-inventory.md) | Diagnostic channel inventory |
| [rea-note.md](rea-note.md) | External REA reference note |

Device UDIDs / Apple ID email in older notes are redacted to placeholders for git. Working local IDs live only in gitignored `Config/local_devices.env`.
| [REPO_PUSH_PLAN.md](REPO_PUSH_PLAN.md) | GitHub private push wait-state; no create from agent |
