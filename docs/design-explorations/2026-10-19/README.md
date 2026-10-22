# 练迹首页视觉探索

日期：2026-10-19（Asia/Shanghai）。最新状态：用户已附图明确选择玻璃底栏第3张，正在按0.2.0实施；本文件保留探索历史，实际落地与结果见../../UI_REDESIGN.md及根目录design-qa.md。

用户反馈当前UI单调，先生成三个不同方向；随后提供底栏参考，要求采用其风格并整体调整。使用内置ImageGen，无CLI/API密钥路径。

## 最新一轮：玻璃底栏

本轮三张图片已按下列顺序在聊天中独立显示。用户若直接说“第1/2/3张”，优先对应本表，不得误选初轮图片。

| 显示序号 | 文件 | 方向 |
|---|---|---|
| 1 | [01-ice-glass.png](../../../artifacts/design-concepts/2026-10-19/glass-nav/01-ice-glass.png) | 冷白冰蓝、通透器械、分层训练面板 |
| 2 | [02-midnight-glass.png](../../../artifacts/design-concepts/2026-10-19/glass-nav/02-midnight-glass.png) | 深岩蓝光、器械摄影、训练焦点 |
| 3 | [03-jade-glass.png](../../../artifacts/design-concepts/2026-10-19/glass-nav/03-jade-glass.png) | 云白青岚、开放内容分区、手账感 |

共同约束：参考图的磨砂半透明大胶囊、淡彩边缘、浅灰选中底座、蓝色选中图标文字；四导航保留首页/训练/统计/我的。原参考见[bottom-reference.png](../../../artifacts/design-concepts/2026-10-19/glass-nav/bottom-reference.png)。

## 初轮归档

图片在artifacts/design-concepts/2026-10-19/initial/：01-charcoal-orange.png、02-glacier-blue.png、03-sage-journal.png，均保留不覆盖。初轮不作为本轮序号对应目标。

## 验证与边界

已查看六个生成结果，主要中文、主按钮与导航均可辨；新一轮底栏体现所给参考。图片是视觉概念，不是Flutter截图或已实现界面。示例数据只存在图片里，没有写入数据库。初轮存在示例未来日期勾选等细节，不能作为计算真值；新轮改为周一1/3及当日最近训练以减少时间矛盾。

落实前仍须处理真实数据/空态、大字体、图文对比度、触达尺寸、安全区、键盘与玻璃模糊性能；不可把概念图片当完整实现或可访问性验收。用户目前只指定底栏风格，尚未选择整体方向。

源提示词见[PROMPTS.md](PROMPTS.md)。本轮只新增设计资料和工作记录，既有0.1.0源码/证据ZIP与签名APK维持此前基线，不含此次探索。选择并实施后再按新版本重新验证和打包。
