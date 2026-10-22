. "$PSScriptRoot/use-toolchain.ps1"
. "$PSScriptRoot/check-toolchain.ps1"
flutter analyze *> artifacts/analyze.log
if ($LASTEXITCODE -ne 0) { Get-Content artifacts/analyze.log; throw '静态检查失败' }
flutter test --reporter expanded *> artifacts/tests.log
if ($LASTEXITCODE -ne 0) { Get-Content artifacts/tests.log; throw '测试失败' }
Write-Output '静态检查及自动测试通过，原始结果见 artifacts/。'
