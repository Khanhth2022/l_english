package com.lenglish.l_english

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

/** Hiển thị lời nhắc ôn tập khi alarm hằng ngày kích hoạt. */
class ReminderReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences(
            ReminderScheduler.PREFS_NAME,
            Context.MODE_PRIVATE
        )
        if (!prefs.getBoolean(ReminderScheduler.KEY_ENABLED, false)) return

        // Android 13+ yêu cầu quyền POST_NOTIFICATIONS; thiếu quyền thì bỏ qua
        // thay vì crash.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        ReminderScheduler.ensureChannel(context)

        val openApp = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_DUE_WORDS
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            ReminderScheduler.NOTIFICATION_ID,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ReminderScheduler.CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_review)
            .setContentTitle("Đến giờ ôn từ vựng")
            .setContentText("Bạn có từ cần ôn hôm nay. Mở LEnglish để ôn ngay.")
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(ReminderScheduler.NOTIFICATION_ID, notification)
    }
}
