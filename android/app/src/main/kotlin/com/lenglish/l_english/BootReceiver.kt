package com.lenglish.l_english

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Khôi phục lịch nhắc sau khi thiết bị khởi động lại. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        ReminderScheduler.rescheduleIfEnabled(context)
    }
}
