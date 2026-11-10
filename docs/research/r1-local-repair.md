# R1 真机诊断入口与本地修复

- `devicectl device process launch --device <Watch UDID> --terminate-existing com.zy.watchhid.watchkitapp -- --r1-start`：仅测试包的显式启动参数，执行与开始广播按钮相同的 probe.start()；不是模拟触控。
- `--r2-probe`：独立运行可选类/方法枚举；不在默认 R1 前置路径执行。
- 日志：App 容器 `Documents/watchhid-r1.log`，每个阶段同步写入，重启与更新保留。屏幕仅显示当前会话，导出包含历史阶段；时间戳为 UTC，汇报时换算 HKT。
- 获取：`devicectl device copy from --device <Watch UDID> --domain-type appDataContainer --domain-identifier com.zy.watchhid.watchkitapp --source Documents/watchhid-r1.log --destination <本机日志路径>`。
- ObjC 类列表只在 C/ObjC 中以 unsafe-unretained Class 读取名字，Swift 仅接收字符串，避免把任意 runtime class 经 Swift AnyClass 持有。
- ObjC addService / startAdvertising 的异常被转换为可持久化的诊断字符串，避免 Swift 无法 catch NSException 导致退出。
- 可读写/notify 特征采用 nil 动态值，避免 CoreBluetooth 的 cached value must be read-only 断言。此包仍是 R1 探针，动态读写处理及完整 HOGP 行为尚未完成，不把广播回调成功视为 HID 服务注册成功。
- 真机截图已确认改用整体滚动布局和显式按钮 label 后，开始/停止广播中文字正常；不宣称已定位 watchOS 渲染器内部原因。
