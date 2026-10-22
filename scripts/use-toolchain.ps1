$ErrorActionPreference = 'Stop'
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path 'L:\AGENTS.md')) {
    if (Test-Path 'L:\') { throw 'L: 已被其他目录占用，请为此项目选用另一个空闲盘符。' }
    subst L: $taskProjectRoot
    if ($LASTEXITCODE -ne 0) { throw '临时盘符映射失败' }
}
$taskAliasProbeName = '.lianji-path-probe-' + [Guid]::NewGuid().ToString('N') + '.tmp'
$taskAliasProbePath = Join-Path $taskProjectRoot $taskAliasProbeName
try {
    [IO.File]::WriteAllText($taskAliasProbePath, 'workspace-alias-check')
    if (-not (Test-Path -LiteralPath (Join-Path 'L:\' $taskAliasProbeName))) {
        throw 'L: 指向其他项目目录，拒绝在错误 checkout 中运行。请先修正临时映射。'
    }
} finally {
    Remove-Item -LiteralPath $taskAliasProbePath -Force -ErrorAction SilentlyContinue
}
if ((Get-Content 'L:\pubspec.yaml' -Raw) -notmatch 'name: lianji') { throw 'L: 不是练迹项目' }
Set-Location 'L:\'
$env:PUB_CACHE = 'L:\.pub-cache'
$env:JAVA_HOME = 'L:\.tooling\jdk17'
$env:ANDROID_HOME = 'L:\.tooling\android-sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:GRADLE_USER_HOME = 'L:\.tooling\gradle-cache'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:Path = "$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;L:\.tooling\flutter\bin;$env:Path"
$env:LIANJI_KEY_PROPERTIES = 'L:\artifacts\private\signing\key.properties'
Remove-Item Env:LIANJI_TEST_BUILD -ErrorAction SilentlyContinue
Remove-Item Env:LIANJI_QA_SUFFIX -ErrorAction SilentlyContinue
