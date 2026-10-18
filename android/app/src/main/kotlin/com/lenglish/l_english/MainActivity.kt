package com.lenglish.l_english

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.lenglish.l_english/widget"
        const val EXTRA_ROUTE = "extra_route"
        const val ROUTE_DUE_WORDS = "due_words"
    }

    private var initialRoute: String? = null
    private var methodChannel: MethodChannel? = null

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
        val route = checkIntentForRoute(intent)
        if (route != null) {
            methodChannel?.invokeMethod("onNavigateRoute", route)
        }
    }

    private fun checkIntentForRoute(intent: Intent?): String? {
        if (intent == null) return null
        return intent.getStringExtra(EXTRA_ROUTE)
    }
}
