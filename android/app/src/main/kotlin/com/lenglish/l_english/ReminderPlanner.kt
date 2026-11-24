package com.lenglish.l_english

import java.util.Calendar
import java.util.TimeZone

/**
 * Phần tính toán thuần của lời nhắc ôn tập.
 *
 * Tách khỏi AlarmManager/NotificationManager để JUnit trên JVM kiểm được luồng
 * "đặt giờ → nhận thông báo → đặt lại giờ" mà không cần thiết bị Android.
 */
object ReminderPlanner {
    const val DEFAULT_HOUR = 20
    const val DEFAULT_MINUTE = 0

    /**
     * Thời điểm kích hoạt kế tiếp của giờ [hour]:[minute], tính bằng millis.
     *
     * Nếu mốc hôm nay vẫn còn ở tương lai thì dùng luôn hôm nay — nhờ vậy đổi
     * giờ sang một mốc muộn hơn trong ngày sẽ có lần nhắc mới ngay, thay vì
     * phải chờ trọn một ngày.
     */
    fun nextTriggerMillis(
        nowMillis: Long,
        hour: Int,
        minute: Int,
        timeZone: TimeZone = TimeZone.getDefault(),
    ): Long {
        val target = Calendar.getInstance(timeZone).apply {
            timeInMillis = nowMillis
            set(Calendar.HOUR_OF_DAY, hour.coerceIn(0, 23))
            set(Calendar.MINUTE, minute.coerceIn(0, 59))
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (target.timeInMillis <= nowMillis) {
            target.add(Calendar.DAY_OF_YEAR, 1)
        }
        return target.timeInMillis
    }

    /**
     * Id riêng cho từng lần báo.
     *
     * Dùng lại một id cố định khiến Android cập nhật im lặng thông báo cũ, nên
     * lần nhắc thứ hai không hiện ra với người dùng.
     */
    fun notificationId(nowMillis: Long): Int = (nowMillis / 1_000L).toInt()
}
