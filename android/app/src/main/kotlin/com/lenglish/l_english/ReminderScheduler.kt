package com.lenglish.l_english

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Lên lịch nhắc ôn tập hằng ngày bằng AlarmManager.
 *
 * Mỗi lần chỉ hẹn MỘT alarm rồi hẹn lại ở lần kế tiếp (xem [scheduleStoredTime])
 * thay vì `setInexactRepeating`: alarm lặp inexact bị hệ thống gom lô/trì hoãn,
 * nên sau lần nhắc đầu, người dùng đổi giờ thì lần sau có thể không bao giờ nổ.
 */
object ReminderScheduler {
    const val PREFS_NAME = "LEnglishReminderPrefs"
    const val KEY_ENABLED = "reminder_enabled"
    const val KEY_HOUR = "reminder_hour"
    const val KEY_MINUTE = "reminder_minute"

    /** Tên hiển thị của người dùng, in vào nội dung thông báo nhắc ôn tập. */
    const val KEY_USER_NAME = "reminder_user_name"

    /** Id thông báo của lần báo gần nhất, để lần sau huỷ trước khi đăng cái mới. */
    const val KEY_LAST_NOTIFICATION_ID = "reminder_last_notification_id"

    /** Đã hỏi quyền báo chính xác một lần chưa (Android 12+), để không mở lại Settings. */
    const val KEY_ASKED_EXACT_ALARM = "reminder_asked_exact_alarm"

    const val ACTION_SHOW_REMINDER = "com.lenglish.l_english.ACTION_SHOW_REMINDER"
    const val CHANNEL_ID = "lenglish_daily_review"
    const val CHANNEL_NAME = "Nhắc ôn tập hằng ngày"

    /** Request code của PendingIntent mở app khi người dùng chạm thông báo. */
    const val CONTENT_INTENT_REQUEST_CODE = 1401

    private const val ALARM_REQUEST_CODE = 1401

    fun schedule(context: Context, hour: Int, minute: Int, userName: String? = null) {
        val safeHour = hour.coerceIn(0, 23)
        val safeMinute = minute.coerceIn(0, 59)

        val editor = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, true)
            .putInt(KEY_HOUR, safeHour)
            .putInt(KEY_MINUTE, safeMinute)

        // Giữ tên cũ nếu lần này không truyền (ví dụ hẹn giờ lại từ màn khác).
        userName?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_USER_NAME, it) }
        editor.apply()

        scheduleStoredTime(context)
    }

    fun cancel(context: Context) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, false)
            .apply()

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(buildPendingIntent(context))
    }

    /** Gọi sau khi khởi động lại máy để đặt lại alarm đã bị hệ thống xoá. */
    fun rescheduleIfEnabled(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        scheduleStoredTime(context)
    }

    /**
     * Hẹn lần nhắc kế tiếp theo giờ đã lưu.
     *
     * Gọi sau mỗi lần alarm nổ (mỗi alarm chỉ chạy một lần) và sau khi khởi
     * động lại máy, nhờ vậy chuỗi nhắc hằng ngày không bị đứt.
     */
    fun scheduleStoredTime(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        ensureChannel(context)
        scheduleNext(
            context,
            ReminderPlanner.nextTriggerMillis(
                System.currentTimeMillis(),
                prefs.getInt(KEY_HOUR, ReminderPlanner.DEFAULT_HOUR),
                prefs.getInt(KEY_MINUTE, ReminderPlanner.DEFAULT_MINUTE)
            )
        )
    }

    /**
     * Cập nhật tên hiển thị dùng cho thông báo mà không đổi giờ nhắc.
     * Gọi khi hồ sơ được tải hoặc người dùng đổi tên.
     */
    fun setUserName(context: Context, userName: String?) {
        val editor = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        val clean = userName?.trim().orEmpty()
        if (clean.isEmpty()) editor.remove(KEY_USER_NAME) else editor.putString(KEY_USER_NAME, clean)
        editor.apply()
    }

    fun readSettings(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return mapOf(
            "enabled" to prefs.getBoolean(KEY_ENABLED, false),
            "hour" to prefs.getInt(KEY_HOUR, ReminderPlanner.DEFAULT_HOUR),
            "minute" to prefs.getInt(KEY_MINUTE, ReminderPlanner.DEFAULT_MINUTE),
            "userName" to (prefs.getString(KEY_USER_NAME, "") ?: "")
        )
    }

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_DEFAULT
        ).apply {
            description = "Nhắc bạn ôn lại các từ đến hạn theo lịch Spaced Repetition."
        }
        manager.createNotificationChannel(channel)
    }

    /**
     * Đặt đúng MỘT alarm (không lặp) tại [triggerAtMillis].
     *
     * Ưu tiên alarm chính xác để "đặt lại giờ" nổ đúng giờ. Nếu app chưa được
     * cấp quyền báo chính xác (Android 12+) thì vẫn đặt alarm sống qua Doze,
     * chỉ có thể trễ vài phút thay vì im lặng cả ngày.
     */
    private fun scheduleNext(context: Context, triggerAtMillis: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context)
        alarmManager.cancel(pendingIntent)

        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms() ->
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )

            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMillis,
                    pendingIntent
                )

            else ->
                @Suppress("DEPRECATION")
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent)
        }
    }

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_SHOW_REMINDER
        }
        return PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
