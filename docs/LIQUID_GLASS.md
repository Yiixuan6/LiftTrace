# 0.2.3 液态玻璃维护说明

用户明确要求最底栏改为液态玻璃，本节取代0.2.2磨砂材质要求。保留70dp胶囊、现有四项图标和独立分支导航；没有业务或数据库变更。

## 实现分类

| 文件 | 责任 |
|---|---|
| assets/shaders/liquid_glass.frag | 背景凸缘法线采样，最大9dp内折射、12dp凸缘、中面清晰，处理DPR/全局原点/GLES翻转 |
| lib/ui/liquid_glass.dart | 启动预载、单个BackdropFilterLayer、shader释放、透明选中透镜、双层高光和栏外阴影 |
| lib/ui/components.dart | 底栏去sigma16雾面和实灰选中底座，保留AnimatedAlign与语义；页面主体在底栏以上结束 |
| lib/main.dart / pubspec.yaml | 预载程序及声明shader；版本0.2.3+5 |
| integration_test/liquid_glass_test.dart | 合成光学条纹，真实GPU折射开/关对照，不读取训练库 |
| integration_test/liquid_navigation_test.dart | 完整App内存空态、真实GPU十次切换采样，绝不打开现有QA数据库 |

引擎自动填充float0–1纹理物理尺寸及sampler。应用填float2=DPR、3–4全局原点、5–6面板逻辑尺寸、7=9dp折射幅度。前景图标文字置于过滤层之上，不参与折射。不叠第二个BackdropFilter，不添加持续动画或新第三方依赖。

首次真实透明巡检曾暴露页面文字透到底栏并与标签重叠（P1）；S044将Scaffold.extendBody改为false以保持文字避让，没有用重度模糊遮挡。失败图以first-overlap-failed命名保留，最终结论见design-qa.md。

S046设备GPU中间帧另发现一次移动亮边截字，S047将四按钮前景Row独立RepaintBoundary后重新采集并查看30帧与原问题局部，未再见截断。该边界是前景合成隔离，不增第二个背景滤镜或改变导航分支。

## 支持与证据边界

Impeller支持ImageFilter.shader时真实背景折射；不支持或加载失败时保留清透高光、0.45轻扩散兼容表面。兼容表面不等于真实折射；宿主Skia截图不能用来证明GPU效果。其他Android版本仍待实机验证。

API36专项实际结果：supported=true、ready=true，边缘开关像素差70.72，中心12.14；已打开0.2.3-gpu-optics-comparison.png核对凸缘弯曲条纹与清晰中面。最终导航原生隔离采样及签名结果以S045之后、PROJECT_STATUS和delivery-manifest为准。

2026-10-20常规QA空库截图保护断言拒绝继续：现有QA已非空。没有清库或把用户记录放进截图；改用MemoryTrainingRepository完整界面采集。不得为了截图清除现有数据或强改偏好。scripts/capture-qa-frames.py仅适用于空QA首页，保护断言必须保留。

0.2.2录屏失败与用户授权重启清理是历史基线；本轮不再启动screenrecord。中间帧排他断言及采样不是连续视频，仍不能保证未采集瞬间的所有闪烁消失。

## 复现顺序

所有Flutter命令串行。先use-toolchain，再以LIANJI_TEST_BUILD=1运行两个integration_test，必须加--no-uninstall且核对.qa标识；测试图只放应用cache。提取测试图后恢复既有签名QA release，保留数据库。正式构建清除LIANJI_TEST_BUILD并用build-release.ps1，不创建新签名。

接口依据：[Flutter片元着色器](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)、[ImageFilter.shader](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html)。实现为本项目单胶囊shader/renderer；坐标处理曾对照MIT just_liquid_glass上游源码，未引入该依赖或交付其源码。临时参考仅在.tooling中。
