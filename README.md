# 当前交付 0.2.10+12

导出默认名称统一为实际应用名＋本地日期。正式版“练迹”已在用户手机安装，完整备份恢复及全量数据保留已核对；旧验证应用保留。最新APK、源码和证据在artifacts/release，仅保留最新版；交接先读S073–S074、PROJECT_STATUS和HANDOFF。

# LiftTrace · 练迹 · 训练日志

GitHub：[Yiixuan6/LiftTrace](https://github.com/Yiixuan6/LiftTrace)。仓库提供 Flutter Android 源码、测试、素材许可和维护文档。`artifacts/`（本机交付及验收证据）、私钥、个人备份、SDK 与构建缓存不上传；下文及历史文档中这些路径指维护者的本机文件，不代表仓库内附带下载。克隆后需按 [构建说明](docs/BUILD.md) 准备工具链；同签名更新还需所有者单独提供已有签名，禁止重建覆盖私钥。

Android 8.0+ 中文离线训练日志。Flutter / Riverpod / go_router / SQLite / Material 3。0.2.9修复发布包休息通知初始化、增加时长沿用与底部跳过；保留0.2.8页面统一与字段/按钮尺寸修正，统计分为概览和逐组动作趋势，详见[页面说明](docs/PAGE_REFRESH.md)。保持云白青岚首页、[液态玻璃底栏](docs/LIQUID_GLASS.md)、紧凑训练操作和动作/组倒序；跨应用提醒与OPPO设置见[提醒说明](docs/REST_REMINDERS.md)。新安装默认冰川蓝，保留已有主题偏好。

| 内容 | 入口 |
|---|---|
| 原始需求 | [docs/PLAN.md](docs/PLAN.md) |
| 完成情况和接手顺序 | [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) |
| 每步改动、失败与证据 | [工作记录/README.md](工作记录/README.md) |
| 架构、数据库、算法 | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| 安装、更新、备份恢复 | [docs/USER_GUIDE.md](docs/USER_GUIDE.md) |
| 主题与组件规范 | [docs/DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md) |
| 本轮视觉落地与对照 | [design-qa.md](design-qa.md)、[docs/UI_REDESIGN.md](docs/UI_REDESIGN.md) |
| 测试与验收 | [docs/ACCEPTANCE.md](docs/ACCEPTANCE.md) |
| 工具、构建和签名 | [docs/BUILD.md](docs/BUILD.md) |

本机检查：`./scripts/verify.ps1`。脚本使用项目内工具链与临时 L:，不改系统 PATH。首次正式库只有动作库和示例模板，无演示训练或身体记录。

旧网站兼容待源码/真实 JSON；实际 WebDAV 兼容待服务。用户已明确批准首次发布签名，固定签名 APK 已构建并验证。设备验收与交付状态以 PROJECT_STATUS 和验收矩阵为准。
