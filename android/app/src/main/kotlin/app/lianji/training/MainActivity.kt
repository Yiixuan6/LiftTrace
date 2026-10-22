package app.lianji.training

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.app.NotificationManager
import android.content.Context
import android.net.Uri

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lianji.training/app-info")
            .setMethodCallHandler { call, result ->
                if (call.method == "getApplicationName") {
                    result.success(applicationInfo.loadLabel(packageManager).toString())
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.lianji.training/reminders")
            .setMethodCallHandler { call, result ->
                if (call.method == "getChannelStatus") {
                    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val channel = manager.getNotificationChannel("rest_alerts_v2")
                    result.success(mapOf(
                        "importance" to (channel?.importance ?: 0),
                        "vibration" to (channel?.shouldVibrate() ?: false)
                    ))
                } else if (call.method == "openBackgroundSettings") {
                    try {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("settings_unavailable", "后台设置暂不可用", null)
                    }
                } else if (call.method == "openNotificationSettings") {
                    try {
                        val appLevel = call.arguments == true
                        val intent = Intent(if (appLevel) Settings.ACTION_APP_NOTIFICATION_SETTINGS
                            else Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        if (!appLevel) intent.putExtra(Settings.EXTRA_CHANNEL_ID, "rest_alerts_v2")
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("settings_unavailable", "通知设置暂不可用", null)
                    }
                } else result.notImplemented()
            }
    }
}
