# Composite keyboard map broke vertical/horizontal pointer movement

Date: 2026-11-10, Asia/Shanghai. Machine: the MacBook that already had a working encrypted HOGP bond with the no-Report-ID mouse Report Map.

What happened:

1. A build with English HID **on** by default published the composite mouse+keyboard Report Map (mouse Report ID 1, keyboard Report ID 2).
2. macOS opened Keyboard Setup Assistant. The operator closed it, as advised, without completing key identification and without resetting Bluetooth.
3. After that, the Watch touchpad could only move the pointer vertically.
4. Turning **English keyboard HID** off in WatchHID Settings republished the baseline no-Report-ID mouse map. The pointer immediately worked again in both axes.

Likely cause, consistent with the reports actually sent: the composite path prefixes each mouse report with Report ID `0x01`, so a 5-byte report `[1, buttons, x, y, wheel]` is sent. If the Mac kept parsing the already bonded 4-byte layout `[buttons, x, y, wheel]`, horizontal movement (`x`) is applied as Y, and vertical movement (`y`) is applied as the wheel. That matches “only up and down.”

Do not use the composite Report Map on a host that already accepted the baseline mouse map. A later keyboard path must keep the mouse Report Map byte-identical and put the keyboard on a separate HID service.
