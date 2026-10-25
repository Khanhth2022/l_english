package com.lenglish.l_english

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.lenglish.l_english/widget"
        const val EXTRA_ROUTE = "extra_route"
        const val ROUTE_DUE_WORDS = "due_words"
        const val ACTION_OPEN_DUE_WORDS = "com.lenglish.l_english.ACTION_OPEN_DUE_WORDS"
    }

    private var initialRoute: String? = null
    private var initialProcessText: String? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialRoute" -> {
                    val route = initialRoute ?: checkIntentForRoute(intent)
                    initialRoute = null
                    result.success(route)
                }
                "getInitialProcessText" -> {
                    val text = initialProcessText ?: checkIntentForProcessText(intent)
                    initialProcessText = null
                    result.success(text)
                }
                "updateWidgetData" -> {
                    val dueCount = call.argument<Int>("dueCount")
                    val accessToken = call.argument<String>("accessToken")
                    val baseUrl = call.argument<String>("baseUrl")

                    val prefs = getSharedPreferences(DueWordsWidgetProvider.PREFS_NAME, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    if (dueCount != null) {
                        editor.putInt(DueWordsWidgetProvider.KEY_DUE_COUNT, dueCount)
                    }
                    if (accessToken != null) {
                        editor.putString(DueWordsWidgetProvider.KEY_ACCESS_TOKEN, accessToken)
                    }
                    if (baseUrl != null) {
                        editor.putString(DueWordsWidgetProvider.KEY_BASE_URL, baseUrl)
                    }
                    editor.apply()

                    DueWordsWidgetProvider.updateAllWidgets(context)
                    result.success(true)
                }
                "pinWidget" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = AppWidgetManager.getInstance(context)
                        val myProvider = ComponentName(context, DueWordsWidgetProvider::class.java)
                        if (appWidgetManager.isRequestPinAppWidgetSupported) {
                            val success = appWidgetManager.requestPinAppWidget(myProvider, null, null)
                            result.success(success)
                        } else {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        // 1. ACT-16: Bôi đen từ bên ngoài (ACTION_PROCESS_TEXT) hoặc Chia sẻ văn bản (ACTION_SEND)
        val processText = checkIntentForProcessText(intent)
        if (!processText.isNullOrBlank()) {
            initialProcessText = processText
            methodChannel?.invokeMethod("onProcessText", processText)
            return
        }

        // 2. ACT-15: Chạm Widget mở phiên câu hỏi ôn tập
        val route = checkIntentForRoute(intent)
        if (route != null) {
            initialRoute = route
            methodChannel?.invokeMethod("onNavigateRoute", route)
        }
    }

    private fun checkIntentForProcessText(intent: Intent?): String? {
        if (intent == null) return null
        return when (intent.action) {
            Intent.ACTION_PROCESS_TEXT -> {
                intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            }
            Intent.ACTION_SEND -> {
                intent.getStringExtra(Intent.EXTRA_TEXT)
                    ?: intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
            }
            else -> null
        }
    }

    private fun checkIntentForRoute(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.action == ACTION_OPEN_DUE_WORDS) {
            return ROUTE_DUE_WORDS
        }
        val extra = intent.getStringExtra(EXTRA_ROUTE)
        if (extra != null) return extra

        val dataString = intent.dataString
        if (dataString != null && (dataString.contains("review") || dataString.contains("due_words"))) {
            return ROUTE_DUE_WORDS
        }
        return null
    }
}
