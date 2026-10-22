# 0.2.4 跨应用组间休息提醒

完成一组后自动开始该动作的休息（未设置时90秒）。可切到视频等其他应用，到时由Android系统弹出“休息结束”并振动。没有应用内全页横幅、悬浮窗或强制全屏覆盖。

## 使用与权限

- 训练页“后台提醒设置”按需申请通知和精确闹钟；首次开始休息只按用户操作请求通知，不在启动时弹权限。
- 页面区分禁通知、横幅未开、振动未开及缺精确权限（可能延迟）。应用总振动/通知关闭时打开本应用通知总设置；通道重要性不足时打开该通道设置。
- 返回系统设置后刷新，对仍在运行的截止时间重新安排。通知点开返回当前训练，没有活动则训练首页。
- OPPO的应用通知总“振动”独立于通道。QA实机总开关原关闭，已通过正常系统界面只开启本应用振动；铃声关闭与勿扰绕过关闭保留。正式与QA标识权限分别管理，不能把QA授权当正式包也已授权。
- 勿扰、用户关闭通知及厂商省电仍可能限制提醒；不绕过这些偏好，不宣传强制停止后无条件提醒。锁屏与长时省电另列待验。
- 本机OPPO“智能优化后台”曾把有精确权限的闹钟延后约三天；只为QA应用正常开启“应用详情→耗电管理→完全允许后台行为”后才恢复准时送达。正式包也需各自配置。训练页“后台运行设置”直接进入本应用详情；该设置可能增加本应用耗电，不改变其他应用或全局省电。

## 分类与维护

| 文件 | 职责 |
|---|---|
| lib/platform/reminders.dart | rest_alerts_v2高重要性、[0,350,150,350,150,500]振动、通知ID71、精确/非精确调度、状态与来源 |
| lib/ui/active_workout.dart | 组完成自动休息、暂停/继续/延长/取消/结束、状态与设置；先持久化截止再改系统安排 |
| lib/main.dart | 初始化不请求权限，恢复截止、通知冷/暖启动回训练 |
| android/.../MainActivity.kt | 按ID只读通道状态，打开本应用/本通道正常设置 |
| AndroidManifest.xml | 明确VIBRATE，保留系统闹钟receiver；无悬浮窗/全屏权限 |
| test/reminders_test.dart、rest_workflow_test.dart | 平台配置/拒权/降级/过期/来源/设置，组与完整休息流程 |
| integration_test/rest_background_test.dart | 带测试VM的原生流程；OPPO切后台断连失败，不能拿它当通过 |
| integration_test/rest_probe_app.dart、scripts/run-rest-device-test.py | 独立QA程序，真实训练页内存组，另一个真实应用在前台，OS送达/振动诊断与安全截图 |

不改schema1、稳定ID或业务范围。重设先撤旧系统闹钟，暂停/取消/结束同步撤销。平台失败保留已完成组与计时并明确提醒不可用；重复提示不堆积，提供关闭按钮。旧rest通道保留，v2新通道不覆盖用户后续设置。

有精确权限时，用户显式启动的短休息使用alarmClock模式，避免普通idle闹钟短间隔配额；仍只发正常通知、不全屏，系统可能显示即将到时的闹钟标志。无精确权限时inexactAllowWhileIdle降级并提示可能延迟。

所有Flutter命令串行。原生测试只用.qa，已有ID71提醒保护拒绝；正式库/现有QA训练库不读不写。独立探针无测试VM连接，防止测试断连后工具强停应用取消待测闹钟。测试结束恢复正常QA release，不留探针入口。

实际结果以rest-background-device.json/log和S050之后记录为准。区分通道配置、OS实际送达、横幅可见、系统振动服务播放及用户亲自感知；这些不是同一结论。Android显示设置是实际其他App，验证跨应用机制，但不是实际视频播放器测试。没有录屏。

2026-10-20 API36实际通过：真实训练页内存组合成完成→后台Android显示设置→截止后334ms观察系统通知；顶部横幅图已打开核对“休息结束”。系统振动记录本次09:27:53.215–09:27:54.746、1531ms、finished。没有要求用户亲自确认手感，因此physicalVibrationUserConfirmed保持false。失败VM/idle模式证据保留，不冒充通过。

依据：[Android通知行为](https://developer.android.com/design/ui/mobile/guides/home-screen/notifications)、[通知通道](https://developer.android.google.cn/develop/ui/compose/notifications/channels?hl=en)、[官方通知插件](https://pub.dev/packages/flutter_local_notifications)。以本地锁定19.5.0源码与实际测试为准，未升级依赖。

## 0.2.9 Release修复（2026-10-21最新）

旧0.2.8发布包被资源裁剪移除了ic_notification，不能用旧Debug提醒测试代替Release验收。raw/keep.xml显式保留资源，初始化使用裸资源名，两个发布脚本实际核对APK图标与receiver。失败状态区分初始化失败和拒权，可重试；没有为解决图标问题新增后台服务或特殊权限。

选择60/90/120秒或自定义会立即开始休息，并把所选时长通过现有仓储保存供后续组沿用；+30不修改默认值，暂停时延长仍保持暂停。底部快速暂停/继续和跳过无需滚回顶部，到零明确显示结束。组记录/排序/稳定ID不变。

当前run-rest-device-test.py固定.qa.design并使用release，先核APK身份/图标再非流式保留安装；不再向真实.qa安装探针。新设计验收标识需先通过正常系统UI配置自己的通知/振动/精确/OPPO后台权限。两轮其他App前台系统投递+振动finished通过；一轮Dozing/AOD熄屏同样通过，1536ms。keyguardLockedConfirmed=false，安全锁屏、用户手感及实际视频播放器不冒称通过。

通知采用官方计时/闹钟CATEGORY_ALARM语义，仍遵守通知和勿扰设置，不全屏。依据：https://developer.android.com/reference/android/app/Notification#CATEGORY_ALARM 。旧0.2.4结果是历史基线，0.2.8 Release缺陷由本节取代。
