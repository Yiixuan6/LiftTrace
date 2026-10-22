param([Parameter(Mandatory=$true)][string]$DeviceId)
. "$PSScriptRoot/use-toolchain.ps1"
$taskAdb=Join-Path $env:ANDROID_HOME 'platform-tools/adb.exe'
$taskRemote='/sdcard/Movies/lianji-qa-navigation-'+[guid]::NewGuid().ToString('N')+'.mp4'
$taskMovie='L:\artifacts\ui-redesign\0.2.2-native-navigation.mp4'
function Assert-TaskQa {
    $taskFocus=(& $taskAdb -s $DeviceId shell dumpsys window | Select-String 'mCurrentFocus') -join "`n"
    if($taskFocus -notmatch 'app.lianji.training.qa/app.lianji.training.MainActivity'){throw 'QA foreground required; recording aborted'}
}
Assert-TaskQa
& $taskAdb -s $DeviceId shell uiautomator dump /data/local/tmp/lianji-qa-ui.xml | Out-Null
$taskXml=(& $taskAdb -s $DeviceId shell cat /data/local/tmp/lianji-qa-ui.xml)-join "`n"
if($taskXml -notmatch '已完成0次' -or $taskXml -notmatch '自由训练'){throw 'Recording requires empty QA home'}
[xml]$taskTree=$taskXml
$taskCoordinates=@{}
foreach($taskLabel in @('首页','训练','统计','我的')) {
    $taskNode=$taskTree.SelectNodes('//node[@package="app.lianji.training.qa"]') | Where-Object {$_.'content-desc' -eq $taskLabel} | Sort-Object { [int]([regex]::Matches($_.bounds,'\d+')[1].Value) } -Descending | Select-Object -First 1
    if(-not $taskNode){throw 'Navigation semantics missing'}
    $taskNums=[regex]::Matches($taskNode.bounds,'\d+')
    $taskCoordinates[$taskLabel]=@([int](([int]$taskNums[0].Value+[int]$taskNums[2].Value)/2),[int](([int]$taskNums[1].Value+[int]$taskNums[3].Value)/2))
}
if((& $taskAdb -s $DeviceId shell pidof screenrecord)-join ''){throw 'Another screen recording exists; refusing to interfere'}
$taskRecord=Start-Process -FilePath $taskAdb -ArgumentList @('-s',$DeviceId,'shell','screenrecord','--size','608x1320','--bit-rate','6000000','--time-limit','12',$taskRemote) -WindowStyle Hidden -PassThru -RedirectStandardOutput 'L:\artifacts\ui-redesign\0.2.2-record.log' -RedirectStandardError 'L:\artifacts\ui-redesign\0.2.2-record-error.log'
$taskRemotePid=$null
try {
    Start-Sleep -Milliseconds 700
    $taskRemotePid=((& $taskAdb -s $DeviceId shell pidof screenrecord)-join '').Trim()
    if($taskRemotePid -notmatch '^\d+$'){throw 'Owned screenrecord process not found'}
    $taskWatch=[Diagnostics.Stopwatch]::StartNew()
    $taskEvents=@()
    foreach($taskLabel in @('训练','统计','我的','首页','我的','统计','训练','首页','训练','首页')) {
        Assert-TaskQa
        $taskXY=$taskCoordinates[$taskLabel]
        $taskTapX=[int]$taskXY[0]
        $taskTapY=[int]$taskXY[1]
        $taskEvents+=('{0}ms {1}' -f $taskWatch.ElapsedMilliseconds,$taskLabel)
        & $taskAdb -s $DeviceId shell input tap $taskTapX $taskTapY
        Start-Sleep -Milliseconds 220
    }
    Assert-TaskQa
    & $taskAdb -s $DeviceId shell kill -2 $taskRemotePid
    if(-not $taskRecord.WaitForExit(10000)){throw 'Screenrecord did not finish'}
    & $taskAdb -s $DeviceId pull $taskRemote $taskMovie | Out-Null
    if($LASTEXITCODE -ne 0){throw 'Recording pull failed'}
    $taskEvents | Set-Content artifacts/ui-redesign/0.2.2-navigation-events.log
    Assert-TaskQa
    & $taskAdb -s $DeviceId exec-out screencap -p > artifacts/device-screenshots/home-0.2.2-android16.png
    Write-Output 'Empty QA home and ten tab changes captured'
} catch {
    if($taskRemotePid -match '^\d+$'){& $taskAdb -s $DeviceId shell kill -2 $taskRemotePid 2>$null}
    if(Test-Path -LiteralPath $taskMovie){Remove-Item -LiteralPath $taskMovie -Force}
    throw
} finally {
    & $taskAdb -s $DeviceId shell rm -f $taskRemote /data/local/tmp/lianji-qa-ui.xml
}
