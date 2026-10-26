# ColorOS 17 流体云可行性（2026-10-26）

本轮仅调研，没有加入SDK、权限、后台服务或卡片。官方文档支持技术可行性，不等同于本应用或用户手机已通过兼容验收；没有找到可替代具体接入文档的一本完整“ColorOS 17开发手册”。

## 两条路线

- **OPPO流体云卡片**：需认证开发者、联系OPPO申请服务ID、意图与授权信息，使用UPK界面和宿主SDK。官方快速开始列出授权元数据`com.oplus.ocs.card.AUTH_CODE`。SDK文档有多倒计时实例，但跨进程更新应离开UI线程；专用卡片资源的获取依赖厂商服务库。因此不把仅依赖本地侧载APK的现有离线App视为已具备接入资格。[快速开始](https://open.oppomobile.com/documentation/page/info?id=12639)、[SDK接入指南](https://open.oppomobile.com/documentation/page/info?id=12719)
- **Android标准Live Updates**：官方支持持续通知、状态栏胶囊及系统计时器，要求符合可提升通知条件并声明`POST_PROMOTED_NOTIFICATIONS`。可以作为先验证的本地通知候选，使用API 36可用的标准样式，不为实验先升级目标SDK。OEM可加条件，不能由Android文档推断ColorOS 17必然把它显示为流体云。[Android官方指南](https://developer.android.com/develop/ui/views/notifications/live-update)
- 请求主动展开面板等厂商能力另有白名单或配置要求，不能当普通SDK方法直接承诺。[流体云卡片设置项](https://open.oppomobile.com/documentation/page/info?id=13330)

## 后续建议与验收门槛

先用`.qa.design`合成休息倒计时验证标准路线：核对真实Android API/ColorOS版本、可提升状态、系统开关和实际胶囊；点击回到当前训练。使用系统chronometer，不用每秒Dart刷新通知。

暂停、继续、延长、取消、到期、结束训练和重启须与原截止时间保持一致；尊重用户关闭/划掉。原闹钟、通知和振动独立保留，胶囊不可用时正常退回原提醒，不引入覆盖层、hook或云端训练数据。

当前设备后续已连接，读取系统属性确认ColorOS V17.0.0 / Android API 37；这只确认系统版本。实际流体云展示、锁屏、后台、用户设置及厂商授权资格均待验证。本轮用户已选择“先调研可行性”，不交付胶囊原型或宣称正式支持。
