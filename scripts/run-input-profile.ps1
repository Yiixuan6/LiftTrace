param([Parameter(Mandatory=$true)][string]$DeviceId)
. "$PSScriptRoot/use-toolchain.ps1"
$env:LIANJI_TEST_BUILD='1'
$env:LIANJI_QA_SUFFIX='.qa.design'
try {
    # Standalone profile application: build + explicitly guarded adb install -r.
    # No Flutter test/drive installation or automatic uninstall path is used.
    flutter build apk --profile --target integration_test/input_profile_app.dart *> artifacts/input-profile-build.log
    if($LASTEXITCODE -ne 0){Get-Content artifacts/input-profile-build.log -Tail 60;throw 'Profile build failed'}
    $taskProfileApk='build/app/outputs/flutter-apk/app-profile.apk'
    $taskProfileInfo=& "$env:ANDROID_HOME/build-tools/36.0.0/aapt.exe" dump badging $taskProfileApk
    if($LASTEXITCODE -ne 0 -or ($taskProfileInfo -join "`n") -notmatch "package: name='app.lianji.training.qa.design'"){throw 'Wrong profile identity'}
    & "$env:ANDROID_HOME/build-tools/36.0.0/apksigner.bat" verify --print-certs $taskProfileApk *> artifacts/input-profile-signature.txt
    if($LASTEXITCODE -ne 0 -or (Get-Content artifacts/input-profile-signature.txt -Raw) -notmatch '2246bdf6a62b0c1e059d56d24b5d556bb046b0f6bfadd5aa2f43a3eefb320944'){throw 'Wrong existing QA certificate'}
    python "$PSScriptRoot/run-input-profile.py" $DeviceId
    if($LASTEXITCODE -ne 0){throw 'Profile probe failed; never uninstall or retry installation'}
} finally {
    Remove-Item Env:LIANJI_TEST_BUILD -ErrorAction SilentlyContinue
    Remove-Item Env:LIANJI_QA_SUFFIX -ErrorAction SilentlyContinue
}
