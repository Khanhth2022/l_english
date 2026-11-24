package com.lenglish.l_english

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Khôi phục lịch nhắc sau khi thiết bị khởi động lại hoặc sau khi cài bản cập
 * nhật: cả hai trường hợp hệ thống đều xoá alarm đã hẹn.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action
        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            ReminderScheduler.rescheduleIfEnabled(context)
        }
    }
}
