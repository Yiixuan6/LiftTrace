# 弯臂图标来源与复现

- 用途：0.2.1首页今日训练/自由训练入口，替换与用户选图不符的哑铃；最近训练与底栏仍使用既有Material图标。
- 官方页面：https://pictogrammers.com/library/mdi/icon/arm-flex/
- 原始矢量：https://raw.githubusercontent.com/Templarian/MaterialDesign/master/svg/arm-flex.svg
- 上游：Pictogrammers Material Design Icons；Apache-2.0。
- assets/icons/arm-flex.svg为原样下载的源文件；SHA256=9c5900691f0eb36b2203587909d8de7309e895f0cc1dd88a4e0db89cd49f74b5。
- assets/icons/arm-flex.png为Sharp按576dpi读SVG、缩放144×144生成的透明黑色PNG；SHA256=20911db893d3b409d5d050cf1538d9c4bb82bda8635a1477fdea237a529746c2。应用32dp显示并按主题着色，无联网请求。
- 复现（安装Sharp的Node运行时中）：`sharp('assets/icons/arm-flex.svg',{density:576}).resize(144,144).png().toFile('assets/icons/arm-flex.png')`。
- 原许可和Apache全文在docs/licenses；随APK打包的assets/licenses/mdi.txt通过LicenseRegistry进入“关于→查看许可”。没有引入新Flutter依赖。
- 本资产是官方图标库资源的无损格式转换，不是手绘或整屏截图裁切。许可通知不得在交付中移除。
## 0.2.2水平哑铃与底栏图标

- 官方Font Awesome Free 6.7.2 solid dumbbell： https://fontawesome.com/icons/dumbbell?f=classic&s=solid 。上游 https://raw.githubusercontent.com/FortAwesome/Font-Awesome/6.x/svgs/solid/dumbbell.svg 。Copyright 2024 Fonticons, Inc.，Icons: CC BY4.0。
- recent-dumbbell.svg原文件SHA256=0fedc5ca02cc6bd53457a1b638ea9fd3e17a82f5601c254bd3844f9f9edec102；Sharp等比例contain至144×144透明PNG，SHA256=e063903b1d7d5ff1820afe24bf2f8128c1a8b8d2370f785e4c6f8711fe2865bc。
- 最近训练行25dp水平显示；底栏训练27dp旋转36度，采用圆角杠铃片轮廓，替换尖角交叉Material图标。只给实际资源主题着色，无手绘替代。
- assets/licenses/fontawesome.txt含作者、来源、CC BY4链接、变更说明与上游全文，关于许可页注册；docs/licenses/Font-Awesome-Free.txt保留上游许可。原MDI弯臂不变。
- 先前下载MDI dumbbell候选实际仍斜置，未采用，两个未注册候选文件已删除，不留误导资产。
