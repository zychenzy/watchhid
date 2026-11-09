# R2 / R3 本机真机阶段

## 已确认
- 保持相同最小特征结构，16位1812/180F/180A注册code8，180D及自定义128位UUID注册成功。限制与服务UUID有关，不是所有16位服务均禁止，也不是原Report Map构造失败。
- 公开CBUUID的两种标准写法在本Ultra2上equal=true，但数据长度分别2/16字节。采用完整Bluetooth-base UUID 00001812/180F/180A-0000-1000-8000-00805F9B34FB后，三个didAddService均OK。未使用私有发送接口、特殊entitlement或修改安全设置。
- Mac正常连接发现完整三个服务及HID特征2A4E/2A4B/2A4D/2A4A/2A4C；同时可区分系统既有180A与本App的完整128位180A。
- iPhone扫描记录收到完整128位HID广告。后续保持完整UUID服务、广告采用16位1812，didAddService仍全部OK，iPhone扫描也收到1812。
- 自定义服务下已实际收到中性4字节Report通知00000000；真实完整HID服务有Report/Battery订阅回调，但不能凭此认定订阅方为iPhone。Mac应用层ATT读出现CBATTErrorDomain242，真实读取链仍需定位；不写作Report Map读已通过。
- iPhone公共GameController GCMouse.mice在23:34 HKT采集为0；这不是系统鼠标识别通过。辅助触控/移动/点击/UU均未验收。

## R2线索排除
- CBStack和CBHIDService实际来自CoreBrightness.framework，不是蓝牙外设发布接口。
- CBStackPeripheral在已加载运行时不存在；HIDUserDevice来自私有HID.framework，是本地HID线索，未证明能向外广播。
- 仅记录类/方法/镜像元数据，未调用private sendMsg/rawCommand/TCC setter、未改系统权限。
- REA官方README已查：原生分析需Hopper/Ghidra/IDA/Kuna提供者。本机未见REA及这些应用，未安装/购买。已有watch调试缓存只有.tmp中部分dyld子缓存和symbols，缺完整主cache；静态符号文本未定位到code8判定函数。
- sanctioned devicectl sysdiagnose返回CoreDeviceCLISupport.DiagnoseError0及隐私声明，未成功采集。LLDB设备attach未形成可继续进程，断点pending、continue提示Process must be launched；已正常重启自己的App恢复，未转而操作系统进程。

## 当前包与下一步
- 默认/CLI case standard128-shortadv保留完整标准服务，广告1812；原standard/custom/形状与UUID矩阵仍可明确选择。
- 新增手表Report订阅计数、用户手动触发“测试右移20”“测试左键点击”，无订阅时禁用；没有自动发送移动/点击，仅测试中发送中性报告。
- 手机--scan记录目标广告及公共系统鼠标连接事件。GATT存在、广告存在、系统鼠标识别、辅助触控、UU分层验收。
- 真正需要本人一步组：iPhone设置退回主列表→蓝牙，观察并仅选择Watch Mouse、按系统流程确认配对（若没有出现不要重配/取消原手表）；启用辅助触控；手表向下滚动看Report订阅，按钮可用后先在安全界面测试右移，再安全位置测试点击；最后手表导出、手机回手表日志。无需用户截图，执行人自行采集。当前设置可能停留Mac mini远程查看/控制授权详情，不是蓝牙页；不点取消配对或停止会话来代替上述动作。

参考：
- https://api.github.com/gists/c606d95d58bbcb50e9715864eeeecf07/comments （2024年完整UUID写法经验，非官方承诺；本项目已本机复测）
- https://stackoverflow.com/questions/20827028/create-ios-ble-hid-service
- https://github.com/morluto/rea
- https://raw.githubusercontent.com/morluto/rea/main/README.md
