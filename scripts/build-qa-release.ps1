. "$PSScriptRoot/use-toolchain.ps1"
. "$PSScriptRoot/check-toolchain.ps1"
if (-not (Test-Path $env:LIANJI_KEY_PROPERTIES)) { throw '缺少已有签名，禁止重建或debug降级' }
$taskQaVersion=[regex]::Match((Get-Content pubspec.yaml -Raw),'(?m)^version:\s*([\d.]+)').Groups[1].Value
$env:LIANJI_TEST_BUILD='1'
try {
    flutter build apk --release *> artifacts/build-qa-release.log
    if($LASTEXITCODE -ne 0){Get-Content artifacts/build-qa-release.log -Tail 60;throw 'QA release构建失败'}
    & "$PSScriptRoot/check-reminder-apk.ps1" -ApkPath 'build/app/outputs/flutter-apk/app-release.apk'
    $taskQaOutput="artifacts/release/lianji-$taskQaVersion-qa.apk"
    Copy-Item -LiteralPath build/app/outputs/flutter-apk/app-release.apk -Destination $taskQaOutput
    & "$env:ANDROID_HOME/build-tools/36.0.0/apksigner.bat" verify --verbose --print-certs $taskQaOutput *> artifacts/qa-release-signature.txt
    if($LASTEXITCODE -ne 0){throw 'QA签名验证失败'}
    Write-Output "正常QA release已构建：$taskQaOutput"
} finally {
    Remove-Item Env:LIANJI_TEST_BUILD -ErrorAction SilentlyContinue
}
