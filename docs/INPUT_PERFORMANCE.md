# 0.2.12 输入性能与数据安全

## 实现

训练会话修改通过`TrainingRepository.saveSession(Session, revision)`只事务UPDATE当前会话和修订号，拒绝不存在的记录及元数据，保留schema1、WAL/FULL及唯一活动会话索引。恢复/跨实体操作仍使用完整事务。Controller只深复制被修改会话；其他记录共享只读引用，后续变更必须继续通过仓储和串行队列，禁止直接修改发布快照。

输入没有固定防抖延迟。`InputSaves`收集已挂载编辑器，明确动作先等待有效输入；失败保留输入并可重试。IME组合未确认时拒绝完成/离开并说明原因，不把拼音或未选定候选词保存为最终备注。监听TextEditingValue，组合结束即使文字没变也保存；不回写小数点、光标或自身保存确认。

`workoutRevision`负责结构变更，逐组版本负责外部及非文本控件刷新；UI文本已即时显示时不再为保存确认重建整组。MaterialApp只订阅品牌/外观/语言；隐藏分支按TickerMode暂停数据订阅，激活后读取最新数据。每秒仅更新计时区域，“上次训练”按历史修订缓存。稳定ID、组/动作倒序及原操作位置保持。

Dock外层青/粉渐变描边改为中性高光，内部选中镜片、图标颜色、阴影和折射shader保留。

## 验证方法与边界

- 主机合成基准：200/1000次历史，每次6动作×8组当前训练、20次串行保存；before/after-host.json仅表示内存仓储保存开销。不能称为真实SQLite速度或手机键盘延迟。
- SQLite：审计触发器证明连续输入只UPDATE当前会话，无INSERT/DELETE；其他记录逐字相同，revision失败全事务回滚，唯一活动约束及缺失ID拒绝；串行输入后完成/关闭重开测试。
- 固定主机窗口断言普通击键和每秒计时不重建整页、其他组、根MaterialApp；隐藏首页/统计不重算，返回后刷新最新逐组曲线并保留动作和子分区。
- 独立`.qa.design`原生功能使用`--no-uninstall`。真实Android键盘insets/lifecycle允许合法布局刷新，因此不把主机固定尺寸的widget identity直接当原生失败。
- 独立Profile探针用UUID临时SQLite、200/1000次合成历史，各60个样本；测程序化TextEditingValue回调至framework endOfFrame，额外采集FrameTiming。APK实际含AOT库、没有debug kernel。通过显式包名/原证书校验后ADB保留安装，没有Flutter自动卸载路径；结果只从该独立包的固定cache文件读取。

当前Profile P95为37.047/36.464ms，满足50ms目标；build P95约26.2ms，仍高于90Hz的11.1ms帧预算，不能宣称所有帧都达90fps。物理输入法触摸到显示的完整延迟、长时间输入及用户主观手感仍待实际使用确认。截图、基准、原生夹具均无真实训练记录。最终具体执行与签名/更新结果见验收矩阵、S090起和artifacts/input-0.2.12/report.json。

## 复验入口

先加载`scripts/use-toolchain.ps1`，所有Flutter命令串行。主机：`flutter test --no-pub`；采集再加`--dart-define=CAPTURE_LOCALIZATION=true --dart-define=CAPTURE_VISUALS=true`。原生：`scripts/run-input-device-test.ps1 -DeviceId <设备>`；Profile：`scripts/run-input-profile.ps1 -DeviceId <设备>`。仅使用`.qa.design`，禁止将夹具安装到正常QA或正式身份。

正式更新必须先通过正常UI导出应用名称＋当天日期完整JSON，校验私有副本，再同签名非流式`install -r`，失败停止；更新后再次导出对比业务实体/ID/时间/设置，禁止卸载或恢复旧快照掩盖差异。
