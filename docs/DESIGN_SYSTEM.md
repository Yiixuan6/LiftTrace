# M3 设计系统

## 0.2.7 内容区统一

首页与液态导航保留原主题；PageBody内使用AppTheme.editorial局部主题。主选项卡使用统一大标题、简短副标题、SectionHeading品牌短线；二级页保留紧凑返回标题。轻量20dp描边面板、分组列表、无重阴影搜索框、品牌色筛选与分段控件共用三品牌六外观。自适应指标按行等高，大字体单列；不通过缩字适配。

训练及历史详情保留操作布局，使用preserveLayout保留16dp原间距；其他页面通常24dp，小于360dp用16dp。图表显示日期/单位/数值，肌群使用横条和文字；详细记录折叠显示。业务数据与界面展示分开，统计只读投影不写回仓储。

AppTheme.build(BrandTheme, Brightness) 为统一颜色入口。0.2.0按用户选图采用云白青岚布局，新安装默认冰川蓝，活力橙、鼠尾草绿共享同一布局，共六套外观；既有偏好不覆盖。system/light/dark独立持久化；启动先恢复偏好，跟随系统实时变化，手动选择固定。不使用壁纸动态取色。

页面从 ColorScheme 语义角色取色，额外颜色集中在 SemanticColors；品牌种子在 ThemeTokens。M3 TextTheme 统一字号/字重/行高，中文系统字体离线可读；计时等宽数字、数字输入右对齐、单位分层。间距刻度 4/8/12/16/20/24/32 dp，卡片圆角 24 dp，主要按钮至少 48 dp，标准主题反馈 180ms；尊重减少动画设置。

共用组件：AppScaffold、WorkoutCard、ExerciseCard、WorkoutSetRow、StatCard、ProgressCard、ThemeSelector、EmptyState、LoadingState、ErrorState。

小于600dp使用共享GlassNavigationBar：0.2.3为清透液态玻璃胶囊、凸缘折射、双层高光和透明选中透镜；支持Impeller时真实背景采样，旧后端为明确兼容降级。保留品牌色图标文字、语义选中状态与四项导航，56dp内容+14dp内边距=70dp并随大字体增高。600dp以上仍NavigationRail；通用内容最大1200dp，首页摄影内容最大840dp。页面主体在底栏以上结束，防止文字透到底栏标签；训练页主操作固定在内容底部，键盘避让，路由返回不结束训练。

暖白基底#faf9f5、青岚文字#07353c集中于ThemeTokens。选图蓝色操作为确保灰色选中底座上小字达到4.5:1，使用#0065cb。静物来自离线PNG，不把整张设计图当交互页面；具体映射、保留入口和对照说明见UI_REDESIGN与design-qa.md。

原生组件提供默认/选中/按下/禁用反馈；保存中防重复，错误就近显示。完成组有文字和勾选反馈；图表附数值/说明。删除须确认，完整恢复先数量预览。主题预览只改局部，“应用外观”才保存；保留路由和输入控制器。

截图脚本 `test/visual_capture_test.dart` 注入隔离测试夹具和中文/Material 图标字体，**不写生产库**。`artifacts/screenshots/` 是 Flutter 渲染截图，不是 Android 实机截图。六套外观主要三页、活力橙明暗其余页面，以及 360×780 / 900×600 / 1280×900 下 200% 字体/减少动画的结果见日志和验收。系统栏、真实键盘与读屏顺序不能仅据截图判通过。

依据：[Flutter M3 组件](https://docs.flutter.dev/ui/widgets/material)、[ColorScheme](https://api.flutter.dev/flutter/material/ColorScheme-class.html)、[Material Design](https://m3.material.io/)。API 以本项目锁定 SDK 的编译结果为准。

### 0.2.1主CTA与切换修正

首页蓝色主按钮与小字primary分开：homeActionColors(light-blue)由#2098f5至#0084ff，19sp/w700白字>=3:1；细亮边0.8dp、22dp模糊柔光。其他五套主题遵循原primary/onPrimary。首页训练入口使用32dp arm-flex PNG主题着色；资产与许可见ICON_ASSET。顶级四标签不播放页面push/pop过渡，选中胶囊仍180ms/减动效0ms；详情保留平台过渡。

### 0.2.2历史底栏（材质已由0.2.3取代）

原四顶级NoTransitionPage方案已按用户反馈撤回，改StatefulShellRoute.indexedStack四分支，保留详情过渡和标签内本地状态。玻璃彩色gradient只画轮廓，禁止以实心DecoratedBox渐变作为“边框”；Light tint约28–38%，Dark fill约60%，真实BackdropFilter模糊。选中胶囊是持续存在的AnimatedAlign，180ms/减动效0ms；不再四个灰底交叉淡入淡出。底栏/侧栏训练图标用官方圆角杠铃资源，最近训练保持水平，来源和许可随包。

### 0.2.3液态玻璃

去掉sigma16和实灰选中底座；单背景shader折射最大9dp，仅凸缘12dp弯曲采样，中面保持清楚。外阴影挖空避免内部蒙灰；细彩色反边与定向亮边表现厚度，不以整面渐变遮住背景。选中层没有第二个背景滤镜。兼容降级和uniform维护见LIQUID_GLASS.md；原图磨砂材质被用户最新液态要求取代，首页/图标/四分支不再重做。

## 0.2.8 标签及按钮尺寸约束

内容区及相关弹窗采用局部editorial主题。输入标签通过FieldCaption排在框外，标签到输入区8dp；动作/组标题到字段12dp。不要将labelText浮动在填充表面边缘。保留输入控制器与语义标签。

本地文件与WebDAV组使用EqualActionGroup：同组同宽高，默认两列、窄屏/大字体单列，按最长标签实测高度，不缩字。Filled/Outlined/Text共享56dp最小高度和内边距；禁用状态只改变语义颜色，不改变尺寸。首页及液态底栏不套局部主题。
