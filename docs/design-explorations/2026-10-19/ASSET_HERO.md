# 云白青岚首页静物头图

- 日期：2026-10-19（北京时间）。分类：A 素材，已生成并目视验证；Flutter整合由主agent执行，未在本素材步骤验证。
- 来源：用户选定的云白青岚界面图，`artifacts/design-concepts/2026-10-19/glass-nav/03-jade-glass.png`；实际工具输入为用户同一张剪贴板图片。
- 工具：内置 `image_gen`，非透明PNG，未用CLI或脚本编辑图像。
- 最终资产：`assets/images/home-hero-jade.png`，1323×1189，RGB不含透明通道，1,825,077字节。保留工具生成原件，复制至项目使用；没有覆盖既有资产。
- 目的：把照片与界面文字分离，使实时标题、日期和业务内容由Flutter渲染。仅包含桌面、哑铃、毛巾、记事本；左上/左下留白，下缘自然融入暖白。
- 检查结果：已查看完整生成图，鼠尾草绿哑铃及5KG、白毛巾、TRAINING LOG记事本符合参考；无UI标题、日期、图标、按钮或导航栏；无真实健康数据。略有物体自然阴影，应由消费端实测实时文字对比度。
- 命令与结果：`view_image`查看参考；内置`image_gen`按下方提示词生成；`view_image`查看输出；`Copy-Item`保存最终PNG；`Get-FileHash`与PNG头读取核验尺寸/摘要。记录文件首次apply_patch因多行前缀格式错误失败，修正后写入；不影响图像。未运行Flutter/浏览器/部署。
- 影响/回滚：仅新增该PNG与本记录；可移除资产引用后删除两文件，无数据库/签名/业务影响。
- 下一步：由主agent整合至HomeHero，验证实际屏幕裁剪、六外观、文字对比度与大字体布局。

## 完整生成提示词

```text
Use case: photorealistic-natural.
Asset type: production raster background hero for a Flutter Android fitness journal, logical display 390 x 350. Create one clean still-life image around 1170 x 1050 pixels or same approximately 1.114:1 width:height ratio.
Input image: reference for objects, natural lighting, warm white and jade color mood; it is NOT an interface to reproduce.
Primary request: extract/re-create only the photographic still-life background from the upper part of the provided selected app design. A soft warm-white tabletop, one matte pale sage-green hex dumbbell with small physical embossed "5KG", folded fluffy white cotton towel at far upper right, cream spiral-bound notebook entering from right with small physical cover text "TRAINING LOG". The dumbbell lies diagonally in upper-right/upper-middle area, matching the pleasing reference forms and natural photography. Warm natural window sunlight and soft leaf/window shadows from upper left, subtle pale sage background at top. Textured realistic materials, calm premium editorial still life.
Composition: equipment occupies mainly the right half and top-middle. Leave the upper-left quarter softly pale and clean for a small live app title, and leave the lower-left and bottom quarter mostly clean warm-white negative space for a live large heading. At bottom, fade naturally into near-white warm tabletop (#faf9f5 approximately), without a hard boundary. The notebook may crop out the right edge. Keep object proportions realistic.
Strict constraints: NO interface content, no app name, no title, no date, no Chinese or UI text, no icons, no buttons, no navigation bar, no status bar, no numbers except physical "5KG" on the dumbbell, no borders or frames, no watermark. Do not retain the lower interface portion of the reference at all. Only permitted physical object text is "5KG" and "TRAINING LOG". Opaque non-transparent PNG.
```

