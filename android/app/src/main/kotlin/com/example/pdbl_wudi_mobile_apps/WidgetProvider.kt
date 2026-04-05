package com.pdbl.wudi

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class WidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: android.content.SharedPreferences) {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            // CRITICAL: Read current_tab from prefs directly, NOT from widgetData
            // because widgetData might be a stale snapshot from Flutter
            val currentTab = prefs.getString("current_tab", "personal") ?: "personal"
            val isLoggedIn = widgetData.getBoolean("is_logged_in", false)
            val hasTeam = widgetData.getBoolean("has_team", false)

            // Update Tab UI
            if (currentTab == "personal") {
                views.setInt(R.id.tab_personal, "setBackgroundResource", R.drawable.tab_selected)
                views.setTextColor(R.id.tab_personal, android.graphics.Color.WHITE)
                views.setInt(R.id.tab_team, "setBackgroundResource", R.drawable.tab_unselected)
                views.setTextColor(R.id.tab_team, android.graphics.Color.parseColor("#333333"))
            } else {
                views.setInt(R.id.tab_team, "setBackgroundResource", R.drawable.tab_selected)
                views.setTextColor(R.id.tab_team, android.graphics.Color.WHITE)
                views.setInt(R.id.tab_personal, "setBackgroundResource", R.drawable.tab_unselected)
                views.setTextColor(R.id.tab_personal, android.graphics.Color.parseColor("#333333"))
            }

            // Tabs Intent
            views.setOnClickPendingIntent(R.id.tab_personal, getPendingSelfIntent(context, "ACTION_TAB_PERSONAL"))
            views.setOnClickPendingIntent(R.id.tab_team, getPendingSelfIntent(context, "ACTION_TAB_TEAM"))

            // Handle States
            if (currentTab == "personal") {
                views.setViewVisibility(R.id.widget_list, View.VISIBLE)
                views.setViewVisibility(R.id.widget_auth_needed, View.GONE)
                views.setViewVisibility(R.id.widget_no_team, View.GONE)
                // Note: widget_empty_view is handled by setEmptyView
            } else {
                if (!isLoggedIn) {
                    views.setViewVisibility(R.id.widget_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_view, View.GONE) // Explicitly hide empty view
                    views.setViewVisibility(R.id.widget_auth_needed, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_no_team, View.GONE)
                    
                    // Use home_widget URI for login redirection
                    val loginIntent = Intent(Intent.ACTION_VIEW, Uri.parse("home_widget://login"))
                    loginIntent.setComponent(ComponentName(context, MainActivity::class.java))
                    val pendingLogin = PendingIntent.getActivity(context, 0, loginIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    views.setOnClickPendingIntent(R.id.btn_login, pendingLogin)
                    views.setOnClickPendingIntent(R.id.widget_auth_needed, pendingLogin)
                } else if (!hasTeam) {
                    views.setViewVisibility(R.id.widget_list, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_view, View.GONE) // Explicitly hide empty view
                    views.setViewVisibility(R.id.widget_auth_needed, View.GONE)
                    views.setViewVisibility(R.id.widget_no_team, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_list, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_auth_needed, View.GONE)
                    views.setViewVisibility(R.id.widget_no_team, View.GONE)
                    // Note: widget_empty_view is handled by setEmptyView
                }
            }

            // Setup ListView - Always refresh the adapter to ensure correct tab data
            val serviceIntent = Intent(context, ListWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                // Append currentTab to data Uri to force list reload on tab change
                data = Uri.parse("wudi://widget/list/$appWidgetId/$currentTab/${System.currentTimeMillis()}")
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty_view)

            // Item Click Intent Template
            val clickIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val clickPendingIntent = PendingIntent.getActivity(
                context, 
                0, 
                clickIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list, clickPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "ACTION_TAB_PERSONAL" || intent.action == "ACTION_TAB_TEAM") {
            val tab = if (intent.action == "ACTION_TAB_PERSONAL") "personal" else "team"
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            prefs.edit().putString("current_tab", tab).commit() // Use commit for immediate write
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, WidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            
            // Trigger update with widget data from HomeWidget
            val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }

    private fun getPendingSelfIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, javaClass)
        intent.action = action
        return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
}
