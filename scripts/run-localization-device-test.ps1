param([Parameter(Mandatory=$true)][string]$DeviceId)
. "$PSScriptRoot/use-toolchain.ps1"
$env:LIANJI_TEST_BUILD='1'
$env:LIANJI_QA_SUFFIX='.qa.design'
try {
    flutter build apk --debug --target integration_test/localization_test.dart *> artifacts/l10n-native-build.log
    if($LASTEXITCODE -ne 0){Get-Content artifacts/l10n-native-build.log -Tail 60;throw 'Isolated preflight build failed'}
    $taskLanguageBadging=& "$env:ANDROID_HOME/build-tools/36.0.0/aapt.exe" dump badging build/app/outputs/flutter-apk/app-debug.apk
    if($LASTEXITCODE -ne 0 -or ($taskLanguageBadging -join "`n") -notmatch "package: name='app.lianji.training.qa.design'"){throw 'Wrong package; refusing installation'}
    flutter test integration_test/localization_test.dart -d $DeviceId --no-uninstall --reporter expanded *> artifacts/l10n-native.log
    $taskLanguageExit=$LASTEXITCODE
    Get-Content artifacts/l10n-native.log -Tail 70
    if($taskLanguageExit -ne 0){throw 'Native localization test failed; no uninstall retry'}
} finally {
    Remove-Item Env:LIANJI_TEST_BUILD -ErrorAction SilentlyContinue
    Remove-Item Env:LIANJI_QA_SUFFIX -ErrorAction SilentlyContinue
}
