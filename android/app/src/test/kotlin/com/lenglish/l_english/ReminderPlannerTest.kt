package com.lenglish.l_english

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * Luồng người dùng: đặt giờ nhắc → nhận thông báo → **đặt lại giờ** → lần nhắc
 * kế tiếp vẫn phải rơi vào giờ mới, không bị dồn sang ngày hôm sau và không bị
 * "câm" ở lần thứ hai.
 */
class ReminderPlannerTest {

    private val timeZone: TimeZone = TimeZone.getTimeZone("Asia/Ho_Chi_Minh")

    private fun at(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int = 0,
    ): Long = Calendar.getInstance(timeZone).apply {
        clear()
        set(year, month - 1, day, hour, minute, second)
    }.timeInMillis

    @Test
    fun `dat lai gio sang moc muon hon trong cung ngay thi nhac ngay hom nay`() {
        val now = at(2026, 11, 24, 22, 16)

        val next = ReminderPlanner.nextTriggerMillis(now, 22, 20, timeZone)

        assertEquals(at(2026, 11, 24, 22, 20), next)
    }

    @Test
    fun `moi lan dat lai gio deu co lich moi thay vi ket o lan dau`() {
        val first = ReminderPlanner.nextTriggerMillis(at(2026, 11, 24, 22, 14), 22, 15, timeZone)
        assertEquals(at(2026, 11, 24, 22, 15), first)

        // Thông báo vừa nổ lúc 22:15; vài giây sau người dùng đổi giờ sang 22:20.
        val second = ReminderPlanner.nextTriggerMillis(first + 1_000, 22, 20, timeZone)
        assertEquals(at(2026, 11, 24, 22, 20), second)
    }

    @Test
    fun `gio da troi qua thi doi sang ngay mai`() {
        val next = ReminderPlanner.nextTriggerMillis(at(2026, 11, 24, 22, 16), 22, 15, timeZone)

        assertEquals(at(2026, 11, 25, 22, 15), next)
    }

    @Test
    fun `dung dung giay hen thi coi nhu da no va doi sang ngay mai`() {
        val next = ReminderPlanner.nextTriggerMillis(at(2026, 11, 24, 22, 15), 22, 15, timeZone)

        assertEquals(at(2026, 11, 25, 22, 15), next)
    }

    @Test
    fun `gio nhac ngoai khoang hop le duoc kep lai thay vi crash`() {
        val next = ReminderPlanner.nextTriggerMillis(at(2026, 11, 24, 10, 0), 25, 61, timeZone)

        assertEquals(at(2026, 11, 24, 23, 59), next)
    }

    @Test
    fun `moi lan bao co id rieng de android hien lai thay vi cap nhat im lang`() {
        val firstFire = ReminderPlanner.notificationId(at(2026, 11, 24, 22, 15, 0))
        val secondFire = ReminderPlanner.notificationId(at(2026, 11, 24, 22, 15, 1))

        assertNotEquals(firstFire, secondFire)
    }
}
