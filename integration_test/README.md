# Android 隔离验收

`./scripts/run-android-tests.ps1 -DeviceId <adb-id>` 使用 `app.lianji.training.qa`，不覆盖正式包；测试只打开应用 cache 内 UUID 命名 SQLite。正式 lianji.db 和个人训练数据不参与测试。

本套件使用 Flutter 的测试构建；执行涉及生成测试构建签名、在设备安装 QA 包和运行测试。当前尚未执行，不能以桌面 Widget 测试代替 Android 运行验收。长期正式发布签名的审批边界另见 BUILD 与工作日志。

覆盖 UI 开始训练、动作选择、数字键盘录入、固定主操作、SQLite 完成组、暂停/继续/结束及关闭重开。后台锁屏通知、精确权限拒绝、系统杀进程、覆盖更新及真实 WebDAV 需额外手工或设备测试，未被本用例覆盖。
# 0.2.0 升级保留补充

`upgrade_preservation_test.dart`必须在仍保留0.1.0验收夹具的同一QA安装上运行：先读recovery-expected.json与recovery-qa.db，核对稳定ID、时间、动作快照、完成组/草稿与设置，schema仍1；不创建替代旧夹具。新手机缺夹具时应列待验，不能伪造通过。此项已在当前API36手机通过，再运行新版workout_flow_test通过。

```powershell
. ./scripts/use-toolchain.ps1
$env:LIANJI_TEST_BUILD='1'
flutter test integration_test/upgrade_preservation_test.dart -d DEVICE_ID --no-uninstall --reporter expanded
Remove-Item Env:LIANJI_TEST_BUILD
```

将DEVICE_ID替换为实际设备，始终串行；正式标识禁止运行这套会由Flutter处理安装失败的测试流程。

