// android/app/src/main/kotlin/com/example/light_alarm_prototype/MainActivity.kt

package com.example.light_alarm_prototype

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "alarm_service"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "alarm_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        createNotificationChannel()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "bringToForeground" -> {
                    bringToForeground()
                    result.success(null)
                }
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "アラーム"
                    val body = call.argument<String>("body") ?: "アラームが鳴っています"
                    val autoCancel = call.argument<Boolean>("autoCancel") ?: true
                    val ongoing = call.argument<Boolean>("ongoing") ?: false
                    showNotification(title, body, autoCancel, ongoing)
                    result.success(null)
                }
                "cancelNotification" -> {
                    cancelNotification()
                    result.success(null)
                }
                "launchAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    val label = call.argument<String>("label") ?: "アラーム"
                    launchAlarmScreen(alarmId, label)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "アラーム通知"
            val descriptionText = "アラームが鳴った時の通知"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setSound(null, null) // 音を無効化（アプリ内で制御）
            }
            
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun bringToForeground() {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                   Intent.FLAG_ACTIVITY_CLEAR_TOP or
                   Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(intent)
    }

    private fun showNotification(title: String, body: String, autoCancel: Boolean, ongoing: Boolean) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent: PendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setAutoCancel(autoCancel)
            .setOngoing(ongoing)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(pendingIntent, true) // フルスクリーン表示を試行

        try {
            with(NotificationManagerCompat.from(this)) {
                notify(NOTIFICATION_ID, builder.build())
            }
        } catch (e: SecurityException) {
            // 通知権限がない場合の処理
            e.printStackTrace()
        }
    }

    private fun cancelNotification() {
        with(NotificationManagerCompat.from(this)) {
            cancel(NOTIFICATION_ID)
        }
    }

    private fun launchAlarmScreen(alarmId: Int, label: String) {
        // アプリを前面に持ってくる
        bringToForeground()
        
        // 通知も表示（バックアップとして）
        showNotification(
            "🚨 アラーム: $label",
            "部屋を明るくしてアラームを停止してください",
            false,
            true
        )
    }
}