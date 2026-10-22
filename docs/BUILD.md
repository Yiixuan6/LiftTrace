# 工具链、构建与发布

## 0.2.7 构建与验收隔离

当前0.2.7+9。`scripts/run-android-tests.ps1`固定使用独立app.lianji.training.qa.design，预构建核对APK标识后才安装，始终带--no-uninstall。现有app.lianji.training.qa已含用户记录，禁止测试流程覆盖；用户更新前完整导出，安装失败不卸载重试。

`scripts/build-qa-release.ps1`生成正常main入口的.qa release；`scripts/build-release.ps1`生成正式app.lianji.training release，两者使用已有签名。use-toolchain清理QA标志，避免遗留.qa.design污染正式标识。APK/签名/公开清单以实际构建结果和delivery-manifest为准。

## 固定基线

- Flutter 3.47.7 stable，framework abaf9c523780a608bd46686fd5e53740a07077f8，Dart 3.13.5，engine deb287481e3ce9468f3434937ced4240a70539ca。
- Microsoft OpenJDK 17.0.16。系统 Java27 不参与构建。
- Android compile/target36、min26、build-tools36.0.0；NDK 用 Flutter 默认。
- AGP9.1.0、Gradle9.3.1、Kotlin插件2.4.0 来自锁定 Flutter 生成的工程。
- Dart 完整依赖以 pubspec.lock 为准，不盲目升级。

官方来源：[Flutter](https://docs.flutter.dev/install)、[Android 工具](https://developer.android.com/studio)、Microsoft JDK 官方下载。Android 命令行包 SHA-256 固定在 download_tools.py。没有改系统 PATH 或关闭 HTTPS 校验。

## 本机复现

```powershell
./scripts/verify.ps1
. ./scripts/use-toolchain.ps1
flutter test test/visual_capture_test.dart --dart-define=CAPTURE_VISUALS=true --reporter expanded
flutter build apk --release --no-pub
```

没有发布配置时最后一个命令仅构建未签名 release。检查真实退出码，使用 apksigner 验证，不能按文件名推断签名。use-toolchain 使用项目内 SDK/JDK/Pub/Gradle cache 和临时 L: 盘符，规避当前 SDK 对空格/中文路径的错误。L: 被其他目录占用时不得覆盖；改脚本盘符并重新 pub get。local.properties 不交付。

临时映射通过随机文件探针确认指向当前 checkout，防止另一份同名工程被误用；探针立即清理。工具链版本由toolchain.lock.json和check-toolchain脚本双重核对。

## 发布签名

2026-10-19 用户明确批准首次签名创建，已执行并验证发布 APK。下列创建命令仅供理解首次流程，**本机已有私钥，不得再次创建或覆盖**；后续仅执行构建：

```powershell
./scripts/create-signing.ps1
./scripts/build-release.ps1
```

脚本拒绝覆盖已有签名。私钥/随机密码/key.properties 位于 artifacts/private/signing，禁止进入源码包/聊天/日志；signing-public-info 只含公开证书信息。独立保管私有目录，后续更新复用证书并记录公开 SHA-256 指纹。

Gradle 从 LIANJI_KEY_PROPERTIES 读取配置，release 不回退 debug 签名；构建脚本验证签名和包 SHA-256。固定 app.lianji.training，递增 pubspec 的 +build。

当前公开证书SHA-256：`2246bdf6a62b0c1e059d56d24b5d556bb046b0f6bfadd5aa2f43a3eefb320944`。0.2.6交付APK为artifacts/release/lianji-0.2.6.apk，脚本从pubspec读取版本命名，不再固定0.1.0；旧APK/ZIP与baseline-0.1.0至0.2.5公开元数据保留。私有目录需由所有者另行备份；源码包不含私钥，因此仅凭源码包不能重现同签名更新。

手机验收使用独立app.lianji.training.qa，debug QA与release QA共用此证书以保留隔离数据；debug QA不交付。Flutter集成测试必须传--no-uninstall（默认会卸载），固定恢复夹具重跑规则见HANDOFF。OPPO首次安装曾出现[-99]/解析提示，非流式安装随后成功；同证书更新安装也成功，准确首因尚未确认，不关闭系统安全设置。

## 新电脑与故障

克隆上述精确 Flutter tag/commit 到 .tooling/flutter，开启该工具仓库 core.longpaths；安装 JDK17/Android36 到脚本位置，核实版本。download_tools.py android|jdk 下载本地工具；完成 license/required packages 后用锁文件 pub get。工具和 cache 均不进交付源码包。

Maven Java TLS 短暂失败可对单个官方 jar 用 `prefetch-maven.py group artifact version`，HTTPS 下载、发布 SHA-1 核验后写 Gradle 内容缓存。不改 TLS/证书/远端地址。

NDK 自动下载曾损坏；`scripts/install-ndk.py` 根据 Google repository2-1.xml 精确获取28.2.13676358，核验官方 SHA-1 后解压。下载归档748118221字节。插件还要求平台34/35和CMake3.22.1，均不改变应用min26/target36。

原 file_picker10 与 Workmanager 的 AGP9 Kotlin 模式不一致，实际编译发现空插件类库。已改为内置 Kotlin=true、newDsl=false，并将 file_picker 锁定13.1.0（Android实现2.1.1），为解决win32依赖冲突将安全存储锁定11.2.0，默认Keystore加密且 resetOnError=false。新版文件选择器使用平台文件流读取，兼容content URI；没有真实旧版凭据/已发布安装包需要迁移。

**Flutter test / pub get / Android build 必须串行**。它们会重写 GeneratedPluginRegistrant；曾因并行测试重写，release错误引用dev-only集成测试插件。不要手工修改生成文件，源码包不携带该文件。正式build不使用--no-pub，并在测试结束后执行。[官方内置Kotlin迁移说明](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)。

发布前以验收矩阵为准：真实服务、设备、旧格式和升级未验证不得宣称通过。源码包排除 SDK/cache/数据库/个人 JSON/私钥/密码；截图标注测试渲染。

## 0.2.8 当前构建与设备隔离

`build-qa-release.ps1`构建普通app.lianji.training.qa的正常main入口，供现有用户数据保留更新；`build-release.ps1`构建正式标识。两者复用原签名。`run-android-tests.ps1`只用app.lianji.training.qa.design，先预构建并aapt核验标识再--no-uninstall；禁止改回含用户记录的.qa。三条Flutter命令串行。

本轮实际QA release58.5秒、正式16.6秒；原生独立预构建28.5秒、测试构建25.1秒、安装5.6秒、21秒通过。aapt处理中文绝对APK路径失败时使用项目相对路径，不重装或降级签名。普通QA保留更新使用非流式-r -t，失败即停止，禁止卸载/清库重试。

## 0.2.9 通知发布门禁

check-reminder-apk.ps1在QA及正式release构建后、交付前检查实际资源表包含drawable/ic_notification，并检查ScheduledNotificationReceiver。raw/keep.xml只保留该图标。不能因Debug包可用就省略Release检查。实际旧0.2.8包被门禁拦截，新0.2.9双包及独立Release通过。

组间休息设备脚本现在固定.qa.design并构建Release；验收external文件仅为合成标记，因为run-as不适用于非debuggable release。真实.qa含用户记录，禁止安装该探针。安装失败不得卸载重试。

## 0.2.10 当前发布

正式版和正常QA均使用既有签名，0.2.10+12；手机日常入口已迁为正式app.lianji.training，旧QA0.2.9和design保留。导出命名通过原生app-info通道读取当前标签，不需要dart-define或新依赖；新原生方法必须随APK更新，不能仅热重载Dart。当前静态检查及59回归、双Release/资源门禁、正式安装与完整恢复核对通过；release仅保留最新十文件。
