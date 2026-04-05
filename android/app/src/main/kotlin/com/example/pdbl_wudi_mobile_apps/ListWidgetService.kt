package com.pdbl.wudi

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

class ListWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return ListRemoteViewsFactory(this.applicationContext)
    }
}

class ListRemoteViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    private var tasks: List<JSONObject> = listOf()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val currentTab = prefs.getString("current_tab", "personal") ?: "personal"
        val dataKey = if (currentTab == "personal") "personal_tasks" else "team_tasks"
        val jsonString = prefs.getString(dataKey, "[]") ?: "[]"
        
        val jsonArray = JSONArray(jsonString)
        val newList = mutableListOf<JSONObject>()
        for (i in 0 until jsonArray.length()) {
            newList.add(jsonArray.getJSONObject(i))
        }
        tasks = newList
    }

    override fun onDestroy() {
        tasks = listOf()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position >= tasks.size) return null

        val task = tasks[position]
        val views = RemoteViews(context.packageName, R.layout.widget_item)

        views.setTextViewText(R.id.widget_item_title, task.optString("title", ""))
        views.setTextViewText(R.id.widget_item_description, task.optString("description", ""))
        views.setTextViewText(R.id.widget_item_date, task.optString("date", ""))
        views.setTextViewText(R.id.widget_item_time, task.optString("time", ""))
        
        val priority = task.optString("priority", "Low").lowercase()
        views.setTextViewText(R.id.widget_item_priority, priority.replaceFirstChar { it.uppercase() })
        
        when (priority) {
            "high" -> {
                views.setInt(R.id.widget_item_priority, "setBackgroundColor", android.graphics.Color.parseColor("#FEE2E2")) // Light Red
                views.setTextColor(R.id.widget_item_priority, android.graphics.Color.parseColor("#991B1B")) // Dark Red
            }
            "medium" -> {
                views.setInt(R.id.widget_item_priority, "setBackgroundColor", android.graphics.Color.parseColor("#FEF3C7")) // Light Orange
                views.setTextColor(R.id.widget_item_priority, android.graphics.Color.parseColor("#92400E")) // Dark Orange
            }
            else -> {
                views.setInt(R.id.widget_item_priority, "setBackgroundColor", android.graphics.Color.parseColor("#DCFCE7")) // Light Green
                views.setTextColor(R.id.widget_item_priority, android.graphics.Color.parseColor("#166534")) // Dark Green
            }
        }

        val currentTab = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .getString("current_tab", "personal") ?: "personal"
        
        val taskId = task.optString("id")
        val teamId = task.optString("team_id")
        
        val fillInIntent = Intent().apply {
            data = android.net.Uri.parse("home_widget://task?id=$taskId&type=$currentTab&team_id=$teamId")
        }
        views.setOnClickFillInIntent(R.id.widget_item_container, fillInIntent)

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
