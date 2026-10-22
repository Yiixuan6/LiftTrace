# 架构、数据库与算法

## 分类与职责

| 路径 | 职责 |
|---|---|
| `lib/domain/models.dart` | 实体、稳定 ID/时间/墓碑、快照、输入与负重口径 |
| `lib/domain/statistics.dart` | 筛选范围、完成量、日期去重、肌群和趋势 |
| `lib/data/repository.dart` | 仓储接口、真实 SQLite、仅测试用内存仓储 |
| `lib/data/backup.dart` | 完整 JSON 版本/摘要/结构校验、分析 CSV |
| `lib/data/webdav.dart` | HTTPS、Keystore 凭据、上传回读和列表 |
| `lib/application/controller.dart` | 串行事务、幂等完成、状态和恢复前备份 |
| `lib/platform/` | Android 闹钟通知、Workmanager 自动备份 |
| `lib/ui/` | M3 主题、通用组件与各功能页面 |
| `test/` | 领域、SQLite、协议、界面及独立截图测试 |
| `scripts/` | 工具准备、检查、构建及交付 |
| `artifacts/` | 原始日志、截图和交付物；private 禁止进入源码包 |

UI 通过 Riverpod 注入 AppController，控制器经 TrainingRepository 访问数据。生产 main 等待数据库与外观偏好加载后再渲染。读取失败不重置数据库，系统能力失败不阻断本地训练。

## 数据库 v1

位置：应用私有 `lianji.db`。WAL / synchronous FULL / 事务。

```sql
CREATE TABLE records (
  kind TEXT NOT NULL, id TEXT NOT NULL, payload TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(kind,id)
);
CREATE UNIQUE INDEX one_active_session ON records(active)
  WHERE kind='session' AND active=1;
CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
```

kind 为 exercise / template / session / measurement；metadata 为 settings / schedule / revision。

首版采用文档记录：会话 payload 包含动作快照与逐组数据。一次保存 records 集合与 metadata，在同一事务替换；中途错误自动回滚。**不删除数据库或重建 schema**。代价是编辑时重写业务记录，数据量大时应迁移为增量写入或独立组表。当前统计在领域层内存计算。

schema `user_version=1`；未来版本必须新增明确迁移和保真测试。缺少迁移时主动失败保护数据，不能清库重建。当前尚无跨多个正式 schema 版本的升级验收。

## 实体与不变量

- 业务实体含 UUID、UTC createdAt/updatedAt、deleted。普通删除保留墓碑，完整恢复显式替换业务集合。
- 会话：标题、起止 UTC、暂停区间、动作顺序、组结果、整体感受/恢复备注。控制器与数据库唯一索引双重保证单活动会话。
- 会话动作：独立 ID、源动作 ID、名称/肌群/器械/类型快照、休息秒、跳过标记和组。
- 组：总或单只 kg、次数、实际左右次数、单双侧、辅助 kg、有氧秒/距离/速度/阻力、完成/时间、感受/身体状态/备注；缺失保留 null。
- 模板开始训练深复制，重建动作/组 ID，清除完成状态和时间；之后改模板不影响历史。
- 控制器 change 串行排队，拷贝状态、写事务，成功后才更新正式内存引用。重复开始/完成幂等。
- 无效输入留在界面并阻止完成；有效草稿及时排队保存。历史新增完成组使用该次结束时间，避免把补记算到今天。
- 身体记录按本地日期，缺失可选，正数校验，不允许同日重复有效记录。

## 统计

| 指标 | 口径 |
|---|---|
| 外部重量 | 总外部 kg × 实际次数 |
| 哑铃 | 单只 kg ×（实际左次数 + 实际右次数） |
| 辅助/有氧/未明确 | 不并入外部负重训练量，保留原字段 |
| 实际完成 | 仅已完成、未删除组，包含活动会话 |
| 训练次数 | 含有效完成组的已结束会话 |
| 训练天数 | 组 completedAt 转本地日期后去重 |
| 时长 | 会话时间扣显式暂停，组间休息保留，筛选区间裁切 |
| 肌群 | 每组仅主要肌群一次 |
| 重量趋势 | 外部总重量 / 哑铃单只重量，不混辅助 |
| 身体趋势 | 缺失跳过，不按零 |

最近 7/30/90 天含今天；本周从周一零时，本月/年从首日起。跨日组按实际完成日期。跳过动作保留已有完成组。空结束会话可保留，但不计有效训练次数。

## 备份协议与恢复

Envelope：format=lianji.full、version=1、exportedAt、payload（JSON 字符串）、payload UTF-8 的 SHA-256。payload 包括完整业务数据、设置、周安排和 revision。50 MiB 上限。摘要检测损坏，不承担加密或身份认证。

恢复：版本/摘要/字段/不变量校验 → 数量预览确认 → 私有 before-restore 目录写恢复前 JSON 并 flush → SQLite 单事务替换 → 更新内存 → 取消设备任务。事务提交前失败保留原数据库。

凭据只在 Android 安全存储，不进入 JSON；权限和设备提醒不迁移。恢复关闭自动备份，换机重新配置服务。CSV 为已完成训练组分析，不用于恢复；字符串公式前缀转文本。

旧网页格式未知：后续先归档去敏样例，明确 ID/日期/重量语义，做冲突预览、追加去重适配；不能用完整替换恢复代替追加导入。

## 系统能力与 WebDAV

通知固定任务 ID 71，休息截止时间持久化，取消/重设/延长撤销旧任务。按需请求通知和精确闹钟，无精确能力时降级非精确后台提醒，保留应用内计时。

WebDAV 仅 HTTPS，拒绝 URL 内凭据和跨目录/跨域访问及重定向，不放宽证书验证。PUT 唯一 partial → GET 校验 → MOVE 唯一 json（禁止覆盖）→ 最终 GET 再校验。只列本目录练迹 JSON，下载验证后才开放恢复。服务需允许 MOVE、目录预先存在；不自动删除远端历史。

自动备份默认关闭，变化后 45 秒合并调度、联网约束、指数重试、6 小时周期补偿。安全存储记录成功 revision，无变化跳过。后台只读数据库，不回写过时快照；失败不阻断本地训练。实际服务/OEM 后台兼容需另行实测。
