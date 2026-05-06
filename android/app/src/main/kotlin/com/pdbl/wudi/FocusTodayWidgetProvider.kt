package com.pdbl.wudi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.app.AlarmManager
import org.json.JSONArray
import com.pdbl.wudi.R
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class FocusTodayWidgetProvider : AppWidgetProvider() {

    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        refreshWidgets(context)
        scheduleNextUpdate(context)
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_focus_today)
            
            val addPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("wudi-widget://add-task")
            )
            views.setOnClickPendingIntent(R.id.btn_add_task, addPendingIntent)

            val intent = Intent(context, FocusTodayWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            
            views.setRemoteAdapter(R.id.widget_list_view, intent)
            views.setEmptyView(R.id.widget_list_view, R.id.widget_empty_view)

            val clickIntentTemplate = Intent(context, FocusTodayWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_CLICK
            }
            val clickPendingIntentTemplate = PendingIntent.getBroadcast(
                context,
                0,
                clickIntentTemplate,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list_view, clickPendingIntentTemplate)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
        }
        
        scheduleNextUpdate(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.pdbl.wudi.ACTION_AUTO_UPDATE") {
            refreshWidgets(context)
            scheduleNextUpdate(context)
        } else if (intent.action == ACTION_WIDGET_CLICK) {
            val uri = intent.data
            if (uri != null) {
                if (uri.host == "toggle-task") {
                    if (isToggleDebounced(context, uri)) {
                        refreshWidgets(context)
                        return
                    }

                    if (!isWidgetTaskLocked(context, uri.getQueryParameter("widget_key"), uri.getQueryParameter("id"))) {
                        toggleTaskInWidgetCache(context, uri.getQueryParameter("widget_key"), uri.getQueryParameter("id"))
                        HomeWidgetBackgroundIntent.getBroadcast(context, uri).send()
                    }
                    refreshWidgets(context)
                } else {
                    val launchIntent = Intent(context, MainActivity::class.java).apply {
                        action = "es.antonborri.home_widget.action.LAUNCH"
                        data = uri
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    context.startActivity(launchIntent)
                }
            }
        }
    }

    private fun refreshWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val componentName = ComponentName(context, FocusTodayWidgetProvider::class.java)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.widget_list_view)
    }

    private fun isToggleDebounced(context: Context, uri: Uri): Boolean {
        val taskKey = uri.getQueryParameter("widget_key") ?: uri.getQueryParameter("id") ?: return false
        val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val key = "widget_toggle_last_$taskKey"
        val now = System.currentTimeMillis()
        val lastToggle = sharedPrefs.getLong(key, 0L)

        if (now - lastToggle < TOGGLE_DEBOUNCE_MS) {
            android.util.Log.d("WUDI_WIDGET", "Debounced widget toggle for $taskKey")
            return true
        }

        sharedPrefs.edit().putLong(key, now).apply()
        return false
    }

    private fun toggleTaskInWidgetCache(context: Context, widgetKey: String?, taskId: String?) {
        if (widgetKey.isNullOrBlank() && taskId.isNullOrBlank()) return

        val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = sharedPrefs.getString("focus_today_tasks", "[]") ?: "[]"

        try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val itemKey = obj.optString("widgetKey", obj.optString("id"))
                if ((!widgetKey.isNullOrBlank() && itemKey == widgetKey) || (widgetKey.isNullOrBlank() && obj.optString("id") == taskId)) {
                    obj.put("isCompleted", !obj.optBoolean("isCompleted", false))
                    break
                }
            }
            sharedPrefs.edit().putString("focus_today_tasks", jsonArray.toString()).apply()
        } catch (e: Exception) {
            android.util.Log.e("WUDI_WIDGET", "Error toggling widget cache: ${e.message}")
        }
    }

    private fun isWidgetTaskLocked(context: Context, widgetKey: String?, taskId: String?): Boolean {
        if (widgetKey.isNullOrBlank() && taskId.isNullOrBlank()) return false

        val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = sharedPrefs.getString("focus_today_tasks", "[]") ?: "[]"

        return try {
            val jsonArray = JSONArray(jsonString)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val itemKey = obj.optString("widgetKey", obj.optString("id"))
                if ((!widgetKey.isNullOrBlank() && itemKey == widgetKey) || (widgetKey.isNullOrBlank() && obj.optString("id") == taskId)) {
                    return obj.optBoolean("isLocked", false)
                }
            }
            false
        } catch (e: Exception) {
            android.util.Log.e("WUDI_WIDGET", "Error reading widget lock state: ${e.message}")
            false
        }
    }

    private fun scheduleNextUpdate(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val intent = Intent(context, FocusTodayWidgetProvider::class.java).apply {
            action = "com.pdbl.wudi.ACTION_AUTO_UPDATE"
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        alarmManager.setExact(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + AUTO_REFRESH_MS, pendingIntent)
    }
    
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        val intent = Intent(context, FocusTodayWidgetProvider::class.java).apply {
            action = "com.pdbl.wudi.ACTION_AUTO_UPDATE"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
    }

    companion object {
        const val ACTION_WIDGET_CLICK = "com.pdbl.wudi.ACTION_WIDGET_CLICK"
        private const val AUTO_REFRESH_MS = 30_000L
        private const val TOGGLE_DEBOUNCE_MS = 3_000L
    }
}
