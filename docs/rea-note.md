# REA 与 WatchHID

Z 提到 [REA](https://github.com/morluto/rea)（含 BLE HCI/ATT/GATT 捕获重建方向，见 issue #3644）可能有帮助。

用法边界：

- REA 适合 **分析** 已有蓝牙抓包、重建对端 GATT；
- WatchHID R1/R2 的目标是让 **手表自己成为外设并广播**；
- 若 R1 广播成功但 iOS 行为怪异，可用 PacketLogger / btsnoop + REA（或 Wireshark）对照广告与 HOGP 交互；
- 不把 REA 当作广播实现本身。
