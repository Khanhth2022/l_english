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

        // Mỗi alarm chỉ chạy MỘT lần: hẹn ngay lần kế tiếp để chuỗi nhắc không
        // đứt — kể cả khi lần này không đăng được thông báo vì thiếu quyền.
        ReminderScheduler.scheduleStoredTime(context)

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
            ReminderScheduler.CONTENT_INTENT_REQUEST_CODE,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ReminderScheduler.CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val userName = prefs.getString(ReminderScheduler.KEY_USER_NAME, "").orEmpty().trim()
        val title = if (userName.isEmpty()) {
            "Đến giờ ôn từ vựng"
        } else {
            "Chào $userName, đến giờ ôn từ vựng"
        }

        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_review)
            .setContentTitle(title)
            // Không khẳng định "có N từ cần ôn": lời nhắc chạy theo giờ, không
            // lọc theo số từ đến hạn nên câu đó có thể sai.
            .setContentText("Mở LEnglish để xem hôm nay bạn cần ôn từ nào.")
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .build()

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Mỗi lần báo dùng một id mới và huỷ thông báo của lần trước: dùng lại
        // một id cố định thì Android chỉ cập nhật im lặng thông báo cũ, người
        // dùng tưởng lần nhắc thứ hai không nổ (và khay bị dồn thông báo).
        val previousId = prefs.getInt(ReminderScheduler.KEY_LAST_NOTIFICATION_ID, -1)
        if (previousId >= 0) manager.cancel(previousId)

        val notificationId = ReminderPlanner.notificationId(System.currentTimeMillis())
        manager.notify(notificationId, notification)
        prefs.edit()
            .putInt(ReminderScheduler.KEY_LAST_NOTIFICATION_ID, notificationId)
            .apply()
    }
}
