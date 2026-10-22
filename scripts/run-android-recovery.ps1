param([Parameter(Mandatory=$true)][string]$DeviceId)
. "$PSScriptRoot/use-toolchain.ps1"
$env:LIANJI_TEST_BUILD='1'
try {
    flutter test integration_test/recovery_test.dart -d $DeviceId --no-uninstall --dart-define=QA_PHASE=seed --reporter expanded *> artifacts/android-recovery-seed.log
    if($LASTEXITCODE -ne 0){Get-Content artifacts/android-recovery-seed.log -Tail 60; throw 'QA recovery seed failed'}
    $taskQaApk='build/app/outputs/flutter-apk/app-debug.apk'
    $taskBadging=& "$env:ANDROID_HOME/build-tools/36.0.0/aapt.exe" dump badging $taskQaApk
    if($LASTEXITCODE -ne 0 -or ($taskBadging -join "`n") -notmatch "package: name='app\.lianji\.training\.qa'"){throw 'Refuse non-QA APK'}
    & adb -s $DeviceId shell am force-stop app.lianji.training.qa *> artifacts/android-recovery-process.log
    if($LASTEXITCODE -ne 0){throw 'QA force-stop failed'}
    Add-Content artifacts/android-recovery-process.log 'QA force-stop returned 0'
    & adb -s $DeviceId shell pidof app.lianji.training.qa >> artifacts/android-recovery-process.log
    if($LASTEXITCODE -eq 0){throw 'QA process survived force-stop'}
    Add-Content artifacts/android-recovery-process.log 'QA pidof returned nonzero: process absent'
    & adb -s $DeviceId install -r -t $taskQaApk >> artifacts/android-recovery-process.log
    if($LASTEXITCODE -ne 0){throw 'QA same-signature reinstall failed'}
    flutter test integration_test/recovery_test.dart -d $DeviceId --no-uninstall --dart-define=QA_PHASE=resume --reporter expanded *> artifacts/android-recovery-resume.log
    if($LASTEXITCODE -ne 0){Get-Content artifacts/android-recovery-resume.log -Tail 60; throw 'QA recovery resume failed'}
    Get-Content artifacts/android-recovery-seed.log -Tail 8
    Get-Content artifacts/android-recovery-resume.log -Tail 8
} finally { Remove-Item Env:LIANJI_TEST_BUILD -ErrorAction SilentlyContinue }
