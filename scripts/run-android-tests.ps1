param([Parameter(Mandatory=$true)][string]$DeviceId)
. "$PSScriptRoot/use-toolchain.ps1"
$env:LIANJI_TEST_BUILD='1'
$env:LIANJI_QA_SUFFIX='.qa.design'
try {
    flutter build apk --debug --target integration_test/workout_flow_test.dart *> artifacts/android-design-preflight.log
    if($LASTEXITCODE -ne 0){Get-Content artifacts/android-design-preflight.log -Tail 50;throw '独立测试包预构建失败'}
    $taskDesignBadging=& "$env:ANDROID_HOME/build-tools/36.0.0/aapt.exe" dump badging build/app/outputs/flutter-apk/app-debug.apk
    if($LASTEXITCODE -ne 0 -or ($taskDesignBadging -join "`n") -notmatch "package: name='app.lianji.training.qa.design'"){throw '测试包标识不正确，拒绝安装'}
    flutter test integration_test/workout_flow_test.dart -d $DeviceId --no-uninstall --reporter expanded *> artifacts/android-integration.log
    $taskAndroidExit=$LASTEXITCODE
    Get-Content artifacts/android-integration.log -Tail 80
    if($taskAndroidExit -ne 0){throw 'Android 集成测试失败'}
    $taskTestVersion=[regex]::Match((Get-Content pubspec.yaml -Raw),'(?m)^version:\s*(\S+)').Groups[1].Value
    Set-Content artifacts/android-integration-version.txt $taskTestVersion
} finally {
    Remove-Item Env:LIANJI_TEST_BUILD -ErrorAction SilentlyContinue
    Remove-Item Env:LIANJI_QA_SUFFIX -ErrorAction SilentlyContinue
}
