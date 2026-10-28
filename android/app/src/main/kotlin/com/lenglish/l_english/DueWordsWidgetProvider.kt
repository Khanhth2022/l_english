package com.lenglish.l_english

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors

/**
 * ACT-15 / SEQ-15: Widget màn hình chính Android hiển thị số từ cần ôn tập.
 * Hỗ trợ:
 * - Cập nhật định kỳ bởi hệ thống Android (onUpdate)
 * - Nút bấm làm mới thủ công trên Widget
 * - Đồng bộ trực tiếp từ Flutter khi người dùng đăng nhập, đổi từ, hoặc ôn tập
 * - Chạm vào widget mở thẳng vào phiên câu hỏi ôn tập của ứng dụng LEnglish
 */
class DueWordsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREFS_NAME = "LEnglishWidgetPrefs"
        const val KEY_DUE_COUNT = "cached_due_count"
        const val KEY_ACCESS_TOKEN = "access_token"
        const val KEY_BASE_URL = "base_url"
        const val KEY_LAST_UPDATED = "last_updated_time"
        const val ACTION_REFRESH_WIDGET = "com.lenglish.l_english.ACTION_REFRESH_WIDGET"

        private val executor = Executors.newSingleThreadExecutor()
        private val mainHandler = Handler(Looper.getMainLooper())

        /**
         * Kích hoạt cập nhật tất cả widget đang hiển thị trên màn hình chính.
         */
        fun updateAllWidgets(context: Context) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, DueWordsWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                val intent = Intent(context, DueWordsWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_REFRESH_WIDGET) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, DueWordsWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                onUpdate(context, appWidgetManager, appWidgetIds)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateWidgetContent(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateWidgetContent(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = SecurePrefs.getToken(prefs)
        val baseUrl = prefs.getString(KEY_BASE_URL, null)
        val cachedCount = prefs.getInt(KEY_DUE_COUNT, -1)

        // 1. Trường hợp chưa đăng nhập
        if (token.isNullOrBlank()) {
            val views = buildRemoteViews(
                context = context,
                appWidgetId = appWidgetId,
                title = "LEnglish • Ôn tập",
                countText = "--",
                statusMessage = "Chưa đăng nhập. Chạm để mở LEnglish.",
                actionHint = "Chạm để đăng nhập →"
            )
            appWidgetManager.updateAppWidget(appWidgetId, views)
            return
        }

        // 2. Nếu đã có bộ nhớ tạm, hiển thị ngay lập tức để người dùng không phải chờ
        if (cachedCount >= 0) {
            val cachedMsg = if (cachedCount == 0) {
                "Đã hoàn thành ôn tập hôm nay!"
            } else {
                "$cachedCount từ cần ôn lại hôm nay"
            }
            val cachedViews = buildRemoteViews(
                context = context,
                appWidgetId = appWidgetId,
                title = "LEnglish • Ôn tập",
                countText = cachedCount.toString(),
                statusMessage = cachedMsg,
                actionHint = "Chạm để ôn tập →"
            )
            appWidgetManager.updateAppWidget(appWidgetId, cachedViews)
        }

        val effectiveBaseUrl = if (baseUrl.isNullOrBlank()) {
            "https://stewart-resource-busy-bristol.trycloudflare.com"
        } else {
            baseUrl.trimEnd('/')
        }

        // 3. Chạy background task gọi GET /api/words/due-count
        executor.execute {
            var fetchedCount: Int? = null
            var isFailure = false

            try {
                val endpoint = "$effectiveBaseUrl/api/words/due-count"
                val url = URL(endpoint)
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "GET"
                    setRequestProperty("Authorization", "Bearer $token")
                    setRequestProperty("Accept", "application/json")
                    connectTimeout = 7000
                    readTimeout = 7000
                    instanceFollowRedirects = true
                }

                val responseCode = conn.responseCode
                if (responseCode in 200..299) {
                    val body = conn.inputStream.bufferedReader().use { it.readText() }
                    conn.disconnect()
                    fetchedCount = parseDueCount(body)
                } else {
                    conn.disconnect()
                    isFailure = true
                }
            } catch (_: Exception) {
                isFailure = true
            }

            mainHandler.post {
                val updatedPrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val finalCount: Int
                val statusText: String
                val actionHint: String

                if (fetchedCount != null) {
                    finalCount = fetchedCount
                    updatedPrefs.edit()
                        .putInt(KEY_DUE_COUNT, finalCount)
                        .putLong(KEY_LAST_UPDATED, System.currentTimeMillis())
                        .apply()
                    statusText = if (finalCount == 0) {
                        "Đã hoàn thành ôn tập hôm nay!"
                    } else {
                        "$finalCount từ cần ôn lại hôm nay"
                    }
                    actionHint = "Chạm để ôn tập →"
                } else if (isFailure) {
                    finalCount = updatedPrefs.getInt(KEY_DUE_COUNT, -1)
                    if (finalCount >= 0) {
                        statusText = "$finalCount từ cần ôn (lỗi mạng, đang dùng dữ liệu cũ)"
                        actionHint = "Chạm để thử lại →"
                    } else {
                        statusText = "Không tải được dữ liệu (chạm để thử lại)"
                        actionHint = "Chạm để mở app →"
                    }
                } else {
                    finalCount = 0
                    statusText = "0 từ cần ôn lại hôm nay"
                    actionHint = "Chạm để ôn tập →"
                }

                val displayCount = if (finalCount >= 0) finalCount.toString() else "!"
                val finalViews = buildRemoteViews(
                    context = context,
                    appWidgetId = appWidgetId,
                    title = "LEnglish • Ôn tập",
                    countText = displayCount,
                    statusMessage = statusText,
                    actionHint = actionHint
                )
                appWidgetManager.updateAppWidget(appWidgetId, finalViews)
            }
        }
    }

    private fun parseDueCount(responseBody: String): Int {
        val trimmed = responseBody.trim()
        if (trimmed.isEmpty()) return 0
        return try {
            val json = JSONObject(trimmed)
            if (json.has("dueCount")) {
                json.getInt("dueCount")
            } else if (json.has("data")) {
                val dataObj = json.optJSONObject("data")
                dataObj?.optInt("dueCount", 0) ?: json.optInt("data", 0)
            } else {
                0
            }
        } catch (_: Exception) {
            trimmed.toIntOrNull() ?: 0
        }
    }

    private fun buildRemoteViews(
        context: Context,
        appWidgetId: Int,
        title: String,
        countText: String,
        statusMessage: String,
        actionHint: String
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_due_words)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_due_count, countText)
        views.setTextViewText(R.id.widget_subtitle, statusMessage)
        views.setTextViewText(R.id.widget_action_hint, actionHint)

        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
        views.setTextViewText(R.id.widget_update_time, "Cập nhật: " + timeFormat.format(Date()))

        // Khi người dùng bấm vào widget -> Mở app vào thẳng phiên câu hỏi ôn tập
        val launchIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_DUE_WORDS
            data = android.net.Uri.parse("lenglish://review")
            putExtra(MainActivity.EXTRA_ROUTE, MainActivity.ROUTE_DUE_WORDS)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, 1001, launchIntent, flags)
        views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

        // Nút refresh góc trên bên phải của widget
        val refreshIntent = Intent(context, DueWordsWidgetProvider::class.java).apply {
            action = ACTION_REFRESH_WIDGET
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context,
            1002 + appWidgetId,
            refreshIntent,
            flags
        )
        views.setOnClickPendingIntent(R.id.widget_btn_refresh, refreshPendingIntent)

        return views
    }
}
