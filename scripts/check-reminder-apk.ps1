param([Parameter(Mandatory=$true)][string]$ApkPath)
$taskReminderResources = & "$env:ANDROID_HOME/build-tools/36.0.0/aapt.exe" dump resources $ApkPath
if ($LASTEXITCODE -ne 0 -or ($taskReminderResources -join "`n") -notmatch ':drawable/ic_notification\b') {
    throw '发布包缺少休息通知图标，拒绝交付。请检查资源保留规则。'
}
$taskReminderManifest = & "$env:ANDROID_HOME/build-tools/36.0.0/aapt.exe" dump xmltree $ApkPath AndroidManifest.xml
if ($LASTEXITCODE -ne 0 -or ($taskReminderManifest -join "`n") -notmatch 'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver') {
    throw '发布包缺少定时通知接收器，拒绝交付。'
}
Write-Output '发布包通知图标及定时接收器核对通过。'
