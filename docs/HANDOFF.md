# 下一位维护者接手

## 首次公开Release v0.1（待用户发布）

对外README已重写；发布说明docs/releases/v0.1.md。artifacts/github-release/v0.1/LiftTrace-v0.1.apk是原正式0.2.10+12 APK的逐字节副本，SHA256SUMS.txt配套，原签名及通知资源本轮实核通过。用户要求v0.1作为公开标签，APK内部版本保持；用户最后选择自行网页发布，未创建标签、未发布Release，也不继续GitHub CLI设备授权。后续不要把附件准备完成记为发布完成。

## 2026-10-22 GitHub 源码仓库

公开远端为 `https://github.com/Yiixuan6/LiftTrace.git`，分支 main；142文件首次上传及本地/远端SHA一致已验证，结果见工作记录/2026-10-22.md。本机origin读取保留HTTPS，pushurl使用ssh.github.com:443及既有github.com主机信任，仓库级固定系统SSH；普通沙箱对.git写入可能被拒，需获准执行上下文。整个 artifacts 仅本机保留，源码库不包含发布 APK、验收截图、真实备份、私钥或 SDK；不能把历史文档中的本机路径当作仓库现有文件。后续提交前核对 `git status`，禁止强制加入被忽略的个人数据。当前应用仍为0.2.10+12，未重新验收业务。

## 0.2.10 正式版迁移（最新）

先读S073–S074与artifacts/export-migration-0.2.10/report.json。用户明确要求所有未来导出使用应用名称＋日期，JSON/CSV/恢复前导出共用exportFilename，Android app-info channel读取实际安装标签，日期用设备本地日历。不要恢复时间戳/英文固定名，也不要为命名改动备份格式。0.2.10+12静态零问题、59回归、同签名双Release与通知门禁通过。

当前手机正式版“练迹”0.2.10已安装并通过正常UI迁入真实记录；完整JSON重新导出逐字段核对全部实体/稳定ID/时间及偏好保持，revision与自动备份沿用原恢复约定。JSON/CSV实际默认名正确，冷启动原训练可见。正式版通知/精确/振动及OPPO完全后台允许已单独配置，未重测本版提醒端到端。旧.qa0.2.9及.qa.design保留，勿卸载/清库；今后用户日常使用正式“练迹”。备份为手机根目录练迹验证-2026-10-21.json及练迹-2026-10-21.json/csv，电脑副本仅artifacts/private/health-exports/2026-10-21。真实记录不得进入公开包/日志/截图。


## 0.2.9 休息修复交接（最新）

先读S069–S072、REST_REMINDERS和design-qa。关键缺陷是Release资源裁剪：通知icon仅从Dart字符串引用，旧Debug测试通过但0.2.8发布包丢资源。res/raw/keep.xml必须保留，两个正式构建脚本都运行check-reminder-apk.ps1，不能只验Debug或宿主mock。初始化失败与拒权必须分开，status可重试初始化。

休息选时长立即开始并保存restPresetSeconds，后续完成组使用所选值，否则沿用动作设置；+30在暂停时保持暂停。底部快速暂停/继续与跳过只控制计时，不完成或删除组。截图异步toImage必须tester.runAsync；布局新测六外观×三状态×四尺寸/字号组合。主页及持久化模型/schema/仓储/统计未改。

当前后台验收脚本固定.qa.design且构建Release，先核包名和实际通知drawable；不使用run-as读取release私有缓存，仅将合成布尔和时间标记放在设计验收包的独立外部目录。需要先通过正常UI给这个新测试标识允许通知、精确闹钟、振动及OPPO后台。--reuse-apk复用已知合成探针；清理失败合成提醒仅在有同版本失败报告证明时显式--clean-own-failed-probe，不能指向真实QA。真实QA只安装正常main入口的同签名release。

两轮其他App+一轮熄屏Dozing的系统通知/服务振动已通过；安全keyguard未确认、用户手感/实际视频播放器/长省电仍待验。手机正常QA已升0.2.9+11，前后完整payload完全一致，USB亮屏设置恢复。完整私有备份保留，139源码文件/461证据完整性通过，release仅留0.2.9，详见S072；以下旧版本保留说明为历史状态。


release目录最新整理结果：当前仅0.2.9正式APK、正常QA APK、源码ZIP、证据ZIP及六个最新校验/清单文件，共10个文件。用户已明确要求只留最新，旧发布包和release内baseline目录已删除；不要按下文历史保留说明寻找这些旧包。原始维护记录与最新验收证据保留，签名和私有备份在原位置。详见S068。

## 0.2.8 页面与圈注修正交接（最新）

先读PAGE_REFRESH.md、design-qa.md、S062起与PROJECT_STATUS。主页面/液态组件及六主题首页保持；PageBody的局部editorial主题不可提升为改变首页的全局卡片主题。活动/历史详情preserveLayout保留操作次序与倒序。统计展示只读，概览不传动作筛选；趋势逐组、按动作ID+LoadKind分开。

字段使用FieldCaption/LabeledTextField外置标签，内层InputDecoration不设labelText，固定8dp间距；不要恢复浮动标签。内部input-标签稳定key用于测试，原controller/validator/onChanged不变。模板FieldGrid负责字号适应；EqualActionGroup按最长文字测量高度，本地文件和WebDAV每组全部操作包括禁用等尺寸；不要改回按内容宽度的Wrap。

实际54默认回归、4组序/7界面专项、96张六外观16状态和四尺寸200%/减动效；.qa.design临时库原生21秒通过，8张GPU合成图。正常.qa已含真实记录，测试绝不能安装到该标识。0.2.8原签名普通QA已保留更新，现有记录与其他业务数据逐字段完整一致；安装前新增记录导致总payload不同，新增记录保留，详见仅布尔报告。不得为追求全payload相等恢复旧备份或删除新增记录。

当前完整签名/归档结果见delivery-manifest、S066–S067。未验其他系统和外部服务保持标注；旧GPU连续帧及跨应用提醒仍各自历史基线。私人备份与签名不进入交付。

## 先读

1. AGENTS.md：数据保护、签名批准和Flutter命令串行要求。
2. PROJECT_STATUS.md：最新结果，不能把旧的“进行中”日志当最终结论。
3. ACCEPTANCE.md：通过/待验/待输入的范围；artifacts原始输出为依据。
4. 工作记录/2026-10-19.md：S001起的决策、失败、修复与命令。
5. ARCHITECTURE / BUILD / USER_GUIDE / DESIGN_SYSTEM。

## 当前数据与边界

0.2.6保留的操作规则：计时/实际完成合并双列卡，新增组/动作入口上移至休息下方；用户追加动作列表也倒序，取代0.2.5仅组倒序边界。active_workout.dart先indexed再reverse，组号/动作原索引、保存/默认完成顺序不变。动作Column和组行均稳定ID key；上移按倒序屏幕方向交换可见邻居（不让删除标记误挡）。单动作直接添组，多动作对话框按ID选目标，可取消；跳过动作不作为目标，零动作先添加。

训练详情共享动作/组倒序，但不含休息卡，故保留其原有逐动作添组和尾部添加动作入口。不要反转数据库数组，不要把输入控制器绑定到视觉位置；删除后组号压缩仍原规则。最新执行结果先看S057之后和PROJECT_STATUS，test/set_order_test.dart覆盖真实新增/复制/编辑/删除、多动作选择/取消、添动作置顶/上移/控制器保留及320dp/200%字体。0.2.8输入标签已外置，底栏材质和提醒保持。

0.2.4+6跨应用组间系统横幅与振动更新保留，先读REST_REMINDERS.md及S048之后。不要做应用内全页面横幅。OPPO本机曾把精确闹钟后台调整约三天，QA需正常系统允许精确闹钟、应用总振动与后台行为才实际通过；不把QA授权当正式标识也已授权。独立内存探针实际334ms送达/可见横幅/1531ms系统振动finished，完整失败和最终归档以S050–S053及delivery-manifest为准。

提醒独立探针不是普通启动入口；交付和手机最后必须恢复正常lib/main.dart的QA release。保留现有训练库/偏好，不截图真实记录；默认保护拒绝已有ID71，--clean-own-failed-probe只能用于有记录证据的本次失败合成探针遗留。普通integration_test rest_background在OPPO断连，不可据其失败扩写业务失败或伪装通过；设备证据来自standalone probe及规范化JSON。液态GPU/30帧采样仍明确0.2.3基线，不冒充0.2.4重跑。

0.2.3+5视觉基线保留“云白青岚”视觉，用户最新要求将底栏从磨砂改成液态玻璃。先读LIQUID_GLASS.md、工作记录/2026-10-20.md、UI_REDESIGN.md与根目录design-qa.md；原图首页仍以artifacts/ui-redesign/selected-reference.png为准，磨砂材质要求已被取代。editorial_home.dart提供真实首页，components.dart提供共享导航，liquid_glass.dart与assets/shaders/liquid_glass.frag负责真实折射。新安装默认blue，既有偏好不覆盖；schema仍1、签名不变。0.1.0–0.2.2交付保留。

2026-10-20 QA已存在使用记录，不得清库取图或擅自覆盖主题。空库采样脚本保护拒绝是正确行为。新增liquid_navigation_test通过MemoryTrainingRepository采集完整App，不打开lianji.db；截图带“native”表示设备GPU渲染，不是连续系统录屏。前景独立RepaintBoundary修正后一轮30图已打开、QA release已恢复/冷启动279ms、已有首页状态保留；打包结果以S047及当前delivery-manifest为准。所有对照图须区分宿主兼容降级和真机shader，旧Android支持仍待验。

首次项目为空，原计划只复制未改；没有导入旧网站、健康档案或任何个人训练数据。生产库只会在安装并启动后创建；初始内容仅动作/示例模板。测试使用临时SQLite和内存仓储；40张渲染图使用测试夹具，另1张实机首页为独立QA release空记录。

用户已明确回复“批准，创建签名并继续验收”。固定发布私钥已首次创建于 artifacts/private/signing，正式 APK 签名校验通过；不要再次执行创建脚本或覆盖私有目录。源码/证据包不含私钥，维护者需由所有者单独取得已有签名。不得以debug证书冒充正式交付签名。

旧网站/JSON与实际WebDAV仍无输入，用户已确认暂时没有；不再反复追问。UI参考已由用户明确选定并落地。旧格式追加导入和真实服务兼容只能在拿到输入后继续。

## 可复现工作

```powershell
./scripts/check-toolchain.ps1
./scripts/verify.ps1
. ./scripts/use-toolchain.ps1
flutter test test/visual_capture_test.dart --dart-define=CAPTURE_VISUALS=true --reporter expanded
flutter build apk --release
```

按顺序执行，**不能并行Flutter命令**。L:临时映射会保留到系统取消映射/重启，不是另一个项目副本，实际文件仍在本工作区。系统Java27不用于构建。所有下载工具/cache在.tooling和.pub-cache，禁止放入源码压缩包。

后续按 BUILD 复用既有签名构建。当前Android测试使用 `run-android-tests.ps1 -DeviceId ...` 的独立 .qa.design 包和UUID临时库，预核实际标识再--no-uninstall。旧 `run-android-recovery.ps1` 是历史夹具流程，禁止对当前含用户数据的.qa直接执行；先迁至独立标识再复验。不能对正式包执行卸载/清库。发布前核对签名指纹、min26/target36、自动云备份关闭、版本码递增。

Android脚本均使用 `--no-uninstall`，Flutter默认结束时会卸载应用，首轮恢复因此失败，已修正。安装失败时Flutter仍可能自动卸载旧包，不能把该流程用于正式标识。QA debug与QA release使用同一个已批准证书，但debug不是交付APK。目前手机保留QA release供查看，测试库不在正常QA主程序使用的lianji.db中。

重复恢复验收前，先保存现有证据，再为测试更换独立夹具文件名（recovery_test.dart中的DB和marker必须同时调整）；也可在确认仍为新建QA测试夹具后仅清理这两个文件及其WAL/SHM。禁止为了重跑测试清空整个正式库或删除生产应用。固定夹具保留是为了审阅，不伪装成可无条件覆盖的脚本。

## 当前重点待验

- 当前已通过：正式APK签名核验，API36 QA release安装/启动/首页、原生训练闭环、强停后同证书同版本覆盖恢复、Keystore往返与提醒安排取消。
- 0.2.0新增已通过：28项默认回归（两截图套件单独运行）、六主题导航对比度、键盘300dp时完成下一组、同状态390×844与真实空态、完整导航触控净空、API36读取0.1.0旧QA夹具覆盖后全量关键记录保留。无schema变更不等于未来schema升级已验证。
- Android 8/9/13：尚未验收；API36仍待飞行模式、省电、锁屏实际送达、拒权/延长、原生键盘/返回完整路径、正式跨版本数据库迁移。
- WebDAV实际服务：连接/认证/断网/空间不足/回读失败/后台重试/换机恢复。
- 原生JSON/CSV导出和content URI恢复在API36/OPPO正常路径已于S061实际通过；其他系统/选择器及实机故障恢复待验，Keystore失败不自动清凭据。

## 变更与回滚

- 业务改动先走controller/repository，不在页面直接写SQLite或私有JSON。
- 新schema必须向前迁移并保真测试；禁止删除重建。当前v1文档式仓储有整份写放大，数据规模优化须单独设计迁移。
- 恢复失败应保留原库；恢复前安全文件在应用私有before-restore，不在源码目录。
- SDK/依赖改动先核对toolchain.lock.json/pubspec.lock与插件Android构建源码，再做分析/领域/SQLite/界面/Android验证。特别注意AGP9内置Kotlin。
- 白名单打包用package-source.py；重新打包前更新状态/日志/验收，以免源码包内状态陈旧。
- 顺序：串行测试 → build-release.ps1 → 更新记录 → package-source.py → verify-delivery.py。最后一项核对ZIP CRC、源码逐文件摘要、排除清单和APK摘要/公开签名证据，生成delivery-manifest.json；新增文件不可遗漏到旧源码包。

## 0.2.1接手重点

- 用户指出首页肌肉图标和主按钮不符、底栏切换页面闪烁重叠；三项已修正，详见工作记录S030起、design-qa及ICON_ASSET。新肌肉PNG、原始SVG和assets/licenses/mdi.txt均必须入包。
- 只四个顶级路由使用NoTransitionPage；详情仍默认平台过渡，未重写数据库/导航状态结构。新中间帧回归要保持不pumpAndSettle：快速8次往返、活动/动作库/外观出口，旧页不得在16ms后仍在场。修复前失败证据保留。
- 亮蓝主按钮单独变量，不要为了匹配按钮提亮底栏小字；19sp粗体白字端点>=3:1，六主题底栏文字>=4.5。持续无障碍/200%布局，其他五套主题保持主题色。
- 本轮30默认回归、两专用截图套件、API36真实训练及新增快速切换保真已通过。旧0.1.0→0.2.0夹具升级、强停恢复/Keystore/提醒仍是各自历史基线，没有伪装成0.2.1新执行。
- 当前版本0.2.1+3，正式lianji-0.2.1.apk，同原签名；0.1.0/0.2.0交付保留，旧公开元数据各自baseline目录。源码103文件（另含manifest）、证据113项的完整性已通过；最终摘要以delivery-manifest为准。

## 0.2.2当前方案（优先于上述0.2.1说明）

- 用户实际反馈推翻0.2.1切换“已解决”的结论；旧报告归档DESIGN_QA_0.2.1，不再用NoTransitionPage。四分支indexedStack保留统计筛选、训练输入/滚动，详情路由和数据库未改。
- 最底栏真正不透明实因是整个胶囊下实心glassRim填色，不是只有tint太高。现在仅描边，内部真实模糊透色；红蓝像素失败/成功证据保留。单一灰色胶囊滑动，56dp内容高+14内边框，200%增高。
- 底栏和最近训练使用Font Awesome dumbbell PNG，底栏36度，最近水平；不要删SVG/PNG及CC BY4作者/许可。当前肌肉与CTA保留。
- verify.ps1、两专用capture已实际通过，31默认回归；API36真实训练/16ms分支排他保真已通过，实际版本写android-integration-version.txt。release原生十次操作录屏/全帧contact由capture-qa-navigation.ps1和inspect-navigation-video.py完成，不能用稳态截图替代动态检查。
- 录屏脚本只在QA空首页工作，前台变化即中止删除录屏，不碰用户已有screenrecord；命令坐标从实际语义节点读取。imageio-ffmpeg0.6仅.tooling/videoqa，排除交付；Python脚本用带PIL的工作区运行时。
- 最终版本/签名/安装/录屏状态以S038及后续实际结果和delivery-manifest为准。其他Android版本/锁屏/WebDAV/原生文件选择器待验项保持。

### OPPO录屏限制与实际证据

当前设备禁止screenrecord写临时目录/Movies；原始流也零输出挂起，系统拒绝终止，用户已授权重启清理。不要在该设备重复尝试screenrecord或为此调整安全设置；capture-qa-navigation.ps1/inspect-navigation-video.py仅保留失败路径的可维护记录，未成功生成视频。

实际动态证据是capture-qa-frames.py的十次切换/30张原生截图、两张contact和0.2.2-native-sequence.json，每次截图前后检查QA前台。读取一帧耗时约0.45–1.28秒，不能排除间隔内短闪；当前采样未见异常，用户复测和连续视频仍待验。重启清理结果看0.2.2-reboot-cleanup.log，禁止把探测进程挂起误报成应用崩溃。

本次录屏探测已在用户明确允许的重启后清理，核对boot_completed=1/pidof无screenrecord/QA仍0.2.2+4，重新打开339ms；不要再因本轮失败提醒用户重复重启。当前可交付为0.2.2 APK/源码/证据；完整录屏和用户实际瞬闪复测保留待验。
