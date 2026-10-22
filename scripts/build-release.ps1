. "$PSScriptRoot/use-toolchain.ps1"
. "$PSScriptRoot/check-toolchain.ps1"
$taskVersionMatch = [regex]::Match((Get-Content pubspec.yaml -Raw), '(?m)^version:\s*([0-9.]+)\+([0-9]+)')
if(-not $taskVersionMatch.Success){throw 'Invalid release version'}
$taskReleaseName = 'lianji-' + $taskVersionMatch.Groups[1].Value + '.apk'
if (-not (Test-Path $env:LIANJI_KEY_PROPERTIES)) { throw '缺少固定发布签名；首次运行 scripts/create-signing.ps1。禁止替换已有签名。' }
flutter build apk --release *> artifacts/build-release.log
if ($LASTEXITCODE -ne 0) { Get-Content artifacts/build-release.log -Tail 100; throw 'APK 构建失败' }
& "$PSScriptRoot/check-reminder-apk.ps1" -ApkPath 'build/app/outputs/flutter-apk/app-release.apk'
New-Item -ItemType Directory -Force -Path 'artifacts/release' | Out-Null
$taskReleasePath=Join-Path 'artifacts/release' $taskReleaseName
Copy-Item -LiteralPath 'build/app/outputs/flutter-apk/app-release.apk' -Destination $taskReleasePath
Get-FileHash -Algorithm SHA256 $taskReleasePath | Format-List *> 'artifacts/release/SHA256.txt'
& "$env:ANDROID_HOME/build-tools/36.0.0/apksigner.bat" verify --verbose --print-certs $taskReleasePath *> 'artifacts/release/signature-verification.txt'
if ($LASTEXITCODE -ne 0) { throw 'APK 签名验证失败' }
Write-Output "签名 APK 已生成并验证：$taskReleasePath"
