package com.lenglish.l_english

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/**
 * Lên lịch nhắc ôn tập hằng ngày bằng AlarmManager.
 *
 * Dùng alarm không chính xác (setInexactRepeating) để không cần quyền
 * SCHEDULE_EXACT_ALARM trên Android 12+, vẫn đủ tốt cho lời nhắc theo giờ.
 */
object ReminderScheduler {
    const val PREFS_NAME = "LEnglishReminderPrefs"
    const val KEY_ENABLED = "reminder_enabled"
    const val KEY_HOUR = "reminder_hour"
    const val KEY_MINUTE = "reminder_minute"

    const val ACTION_SHOW_REMINDER = "com.lenglish.l_english.ACTION_SHOW_REMINDER"
    const val CHANNEL_ID = "lenglish_daily_review"
    const val CHANNEL_NAME = "Nhắc ôn tập hằng ngày"
    const val NOTIFICATION_ID = 1401

    private const val REQUEST_CODE = 1401
    private const val DEFAULT_HOUR = 20
    private const val DEFAULT_MINUTE = 0

    fun schedule(context: Context, hour: Int, minute: Int) {
        val safeHour = hour.coerceIn(0, 23)
        val safeMinute = minute.coerceIn(0, 59)

        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, true)
            .putInt(KEY_HOUR, safeHour)
            .putInt(KEY_MINUTE, safeMinute)
            .apply()

        ensureChannel(context)

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = buildPendingIntent(context)
        alarmManager.cancel(pendingIntent)

        val triggerAt = nextTriggerMillis(safeHour, safeMinute)
        alarmManager.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            triggerAt,
            AlarmManager.INTERVAL_DAY,
            pendingIntent
        )
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
        schedule(
            context,
            prefs.getInt(KEY_HOUR, DEFAULT_HOUR),
            prefs.getInt(KEY_MINUTE, DEFAULT_MINUTE)
        )
    }

    fun readSettings(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return mapOf(
            "enabled" to prefs.getBoolean(KEY_ENABLED, false),
            "hour" to prefs.getInt(KEY_HOUR, DEFAULT_HOUR),
            "minute" to prefs.getInt(KEY_MINUTE, DEFAULT_MINUTE)
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

    private fun buildPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, ReminderReceiver::class.java).apply {
            action = ACTION_SHOW_REMINDER
        }
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun nextTriggerMillis(hour: Int, minute: Int): Long {
        val now = Calendar.getInstance()
        val target = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (!target.after(now)) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }
        return target.timeInMillis
    }
}
