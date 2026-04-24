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
        val tabPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val currentTab = tabPrefs.getString("current_tab", "personal") ?: "personal"

        // KEMBALIKAN KE MENGGUNAKAN HomeWidgetPlugin KARENA FLUTTER MENYIMPANNYA DI SINI
        val widgetPrefs = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        val dataKey = if (currentTab == "personal") "personal_tasks" else "team_tasks"
        val jsonString = widgetPrefs.getString(dataKey, "[]") ?: "[]"

        android.util.Log.d("WUDI_WIDGET", "Loading $currentTab data. JSON length: ${jsonString.length}")

        val newList = mutableListOf<JSONObject>()
        try {
            if (jsonString.isNotBlank() && jsonString != "null") {
                val jsonArray = JSONArray(jsonString)
                for (i in 0 until jsonArray.length()) {
                    newList.add(jsonArray.getJSONObject(i))
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("WUDI_WIDGET", "Error parsing JSON tasks: ${e.message}")
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
        val priorityText = priority.replaceFirstChar { it.uppercase() } + " Priority"
        views.setTextViewText(R.id.widget_item_priority, priorityText)

        when (priority) {
            "high" -> {
                views.setInt(R.id.widget_item_priority, "setBackgroundResource", R.drawable.widget_pill_high)
                views.setTextColor(R.id.widget_item_priority, android.graphics.Color.parseColor("#E24B4A"))
            }
            "medium" -> {
                views.setInt(R.id.widget_item_priority, "setBackgroundResource", R.drawable.widget_pill_medium)
                views.setTextColor(R.id.widget_item_priority, android.graphics.Color.parseColor("#BA7517"))
            }
            else -> {
                views.setInt(R.id.widget_item_priority, "setBackgroundResource", R.drawable.widget_pill_low)
                views.setTextColor(R.id.widget_item_priority, android.graphics.Color.parseColor("#3B6D11"))
            }
        }

        val teamId = task.optString("team_id")
        if (teamId.isNotEmpty() && teamId != "null") {
            views.setViewVisibility(R.id.widget_item_team, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_item_team, android.view.View.GONE)
        }

        val assignTo = task.optString("assign_to", "")
        if (assignTo.isNotEmpty() && assignTo != "null") {
            views.setViewVisibility(R.id.widget_item_assignee, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_item_assignee, "Assign: $assignTo")
        } else {
            views.setViewVisibility(R.id.widget_item_assignee, android.view.View.GONE)
        }

        val description = task.optString("description", "")
        if (description.isEmpty() || description == "null") {
            views.setViewVisibility(R.id.widget_item_description, android.view.View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_item_description, android.view.View.VISIBLE)
            views.setTextViewText(R.id.widget_item_description, description)
        }

        val currentTab = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .getString("current_tab", "personal") ?: "personal"

        val taskId = task.optString("id")

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
