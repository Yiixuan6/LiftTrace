. "$PSScriptRoot/use-toolchain.ps1"
$taskPin=Get-Content 'docs/toolchain.lock.json' -Raw | ConvertFrom-Json
$taskActual=flutter --version --machine | ConvertFrom-Json
if($LASTEXITCODE -ne 0){throw 'Flutter 版本读取失败'}
if($taskActual.frameworkRevision -ne $taskPin.frameworkRevision -or $taskActual.dartSdkVersion -ne $taskPin.dart){throw 'SDK 与工具链锁不一致；禁止静默升级后验收'}
Write-Output "工具链匹配：Flutter $($taskPin.flutter) / Dart $($taskPin.dart)"
