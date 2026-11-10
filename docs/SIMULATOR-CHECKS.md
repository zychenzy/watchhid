# Simulator checks and limits

## Environment
the development Mac uses existing watchOS27.2 runtime24S118, simulated Apple Watch Ultra4(49mm), UDID SIMULATOR_UDID. Physical device is Ultra2, so this is not an exact hardware match. No runtime downloaded. Free disk before8.1GiB; after boot/build about7.4GiB.

## Actually exercised
- Current watchOS Simulator build succeeded. Headless simctl install and launch succeeded; process liveness was checked.
- Settled main screenshot shows large pad and orange语音听写 button. It says等待Mac系统订阅 because simulator CoreBluetooth peripheral state is unsupported. This is expected, NOT BLE HID acceptance.
- Simulator-only --simulator-text-entry invokes the same actual public system input method as the button. Screenshot confirms the system keyboard appears. This proves presentation works, not that the simulator performed speech recognition or returned a user-entered String.
- --simulator-sample-preview presents the explicit synthetic text SIMULATOR SAMPLE—not speech. Screenshot confirms preview layout, Done action visibility, and no automatic Mac input. This is mock data, NOT ASR.
- --simulator-sample-preview --simulator-dismiss-preview clears preview programmatically after3seconds; a separate screenshot/log records return to the main pad. This is a state/rendering check, not a physical tap test.
- Pure mouse/keyboard/metadata tests and12 existing evidence-gate tests passed. Coverage includes tap-left, hold-right/release, inactive release, subscription loss, no stale-motion replay, cached metadata bytes and report-map modes.

## Cannot claim from these checks
No real BLE HOGP or system Mac cursor success, no voice ASR, no microphone availability, no proof of physical drag/tap recognition, no user-entered system text completion callback, no guarantee watchOS remembers the microphone input mode. Simulator-only arguments are compiled out of physical-device builds; no mock data runs by default.

## Optional next native GUI task for a capable desktop agent
Open this already-booted watch simulator, launch with --simulator-text-entry, use the visible keyboard to enter a harmless sample and click Done; verify actual completion log and preview; click完成 and return. Separately verify Cancel, keyboard-mode menu, and any available Dictation option. Do not report typed sample as speech ASR. Do not inject Mac mouse input or alter phone/network/BT settings. No native GUI tool was available in this executor, so desktop was not driven through Shell.

## Evidence
the development Mac path `build/diagnostics/recovery-root/`:
`simulator-main-ready.png`, `simulator-system-text-entry.png`, `simulator-synthetic-preview.png`, `simulator-return-to-pad.png`, corresponding log files and `build-watchsim-harness.log`.
