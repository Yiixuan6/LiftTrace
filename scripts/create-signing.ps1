. "$PSScriptRoot/use-toolchain.ps1"
$taskSigningDir = 'L:\artifacts\private\signing'
New-Item -ItemType Directory -Force -Path $taskSigningDir | Out-Null
if (Test-Path "$taskSigningDir/lianji-release.jks") { throw '签名已经存在，拒绝覆盖。' }
$taskPassword = [Convert]::ToBase64String([System.Security.Cryptography.RandomNumberGenerator]::GetBytes(36))
[IO.File]::WriteAllText("$taskSigningDir/password.txt", $taskPassword)
& "$env:JAVA_HOME/bin/keytool.exe" -genkeypair -keystore "$taskSigningDir/lianji-release.jks" -alias lianji -keyalg RSA -keysize 3072 -validity 10000 -storepass:file "$taskSigningDir/password.txt" -keypass:file "$taskSigningDir/password.txt" -dname 'CN=Lianji Personal Training, OU=Personal, O=Lianji, C=CN' -noprompt
if ($LASTEXITCODE -ne 0) { throw '生成签名失败' }
[IO.File]::WriteAllText("$taskSigningDir/key.properties", "storeFile=lianji-release.jks`nstorePassword=$taskPassword`nkeyPassword=$taskPassword`nkeyAlias=lianji`n")
$taskPassword = $null
& "$env:JAVA_HOME/bin/keytool.exe" -list -v -keystore "$taskSigningDir/lianji-release.jks" -storepass:file "$taskSigningDir/password.txt" *> 'artifacts/signing-public-info.txt'
Write-Output '签名已创建；私钥和密码位于 artifacts/private/signing，禁止纳入源码压缩包。'
