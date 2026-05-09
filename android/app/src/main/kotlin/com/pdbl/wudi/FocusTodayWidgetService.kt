package com.pdbl.wudi

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.*
import android.graphics.Color

class FocusTodayWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return FocusTodayWidgetFactory(this.applicationContext)
    }
}

class FocusTodayWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks = mutableListOf<TaskData>()
    data class TaskData(val id: String, val widgetKey: String, val title: String, val dueTime: String, val priority: String, val isTeam: Boolean, val teamId: String, val isCompleted: Boolean, val isLocked: Boolean)

    override fun onCreate() {}

    override fun onDataSetChanged() {
        tasks.clear()
        val sharedPrefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = sharedPrefs.getString("focus_today_tasks", "[]") ?: "[]"
        
        val calNow = Calendar.getInstance()
        val currentHour = calNow.get(Calendar.HOUR_OF_DAY)
        val currentMinute = calNow.get(Calendar.MINUTE)
        
        try {
            val jsonArray = JSONArray(jsonString)
            android.util.Log.d("WUDI_WIDGET", "Loading ${jsonArray.length()} tasks from sharedPrefs")
            
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.getJSONObject(i)
                val timeStr = obj.optString("dueTime", "")
                val isTeam = obj.optBoolean("isTeam", false)
                val idStr = obj.optString("id", "")
                val widgetKey = obj.optString("widgetKey", idStr)
                val teamIdStr = obj.optString("team_id", "")
                val isCompleted = obj.optBoolean("isCompleted", false)
                val isLocked = obj.optBoolean("isLocked", false)
                val title = obj.optString("title", "Untitled")
                val priority = obj.optString("priority", "low")
                
                val parsedTime = parseTime(timeStr)
                if (parsedTime != null && isPastDue(parsedTime, calNow)) {
                    continue
                }
                
                tasks.add(TaskData(
                    id = idStr,
                    widgetKey = widgetKey,
                    title = title,
                    dueTime = if (parsedTime != null) formatDisplayTime(parsedTime) else timeStr,
                    priority = priority,
                    isTeam = isTeam,
                    teamId = teamIdStr,
                    isCompleted = isCompleted,
                    isLocked = isLocked
                ))
            }
        } catch (e: Exception) { 
            android.util.Log.e("WUDI_WIDGET", "Error parsing tasks JSON: ${e.message}")
            e.printStackTrace() 
        }
    }

    private fun isPastDue(taskTime: Calendar, now: Calendar): Boolean {
        val taskHour = taskTime.get(Calendar.HOUR_OF_DAY)
        val taskMinute = taskTime.get(Calendar.MINUTE)
        val currentHour = now.get(Calendar.HOUR_OF_DAY)
        val currentMinute = now.get(Calendar.MINUTE)

        return taskHour < currentHour || (taskHour == currentHour && taskMinute < currentMinute)
    }

    private fun parseTime(timeStr: String): Calendar? {
        try {
            val sdf = SimpleDateFormat("h:mm a", Locale.ENGLISH)
            val date = sdf.parse(timeStr) ?: return null
            return Calendar.getInstance().apply { time = date }
        } catch (e: Exception) {
             try {
                 val sdf2 = SimpleDateFormat("HH:mm", Locale.ENGLISH)
                 val date2 = sdf2.parse(timeStr) ?: return null
                 return Calendar.getInstance().apply { time = date2 }
             } catch (e2: Exception) { return null }
        }
    }

    private fun formatDisplayTime(cal: Calendar): String {
        val is24Hour = android.text.format.DateFormat.is24HourFormat(context)
        val pattern = if (is24Hour) "HH:mm" else "h:mm a"
        val sdf = SimpleDateFormat(pattern, Locale.getDefault())
        return sdf.format(cal.time)
    }

    override fun getCount(): Int = tasks.size
    
    override fun getViewAt(position: Int): RemoteViews {
        val task = tasks[position]
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)
        
        views.setTextViewText(R.id.tv_task_title, task.title)
        views.setTextViewText(R.id.tv_task_time, "Time : ${task.dueTime}")
        
        when (task.priority.lowercase(Locale.ROOT)) {
            "high" -> {
                views.setTextViewText(R.id.tv_priority, "High Priority")
                views.setTextColor(R.id.tv_priority, Color.parseColor("#C64141"))
                views.setInt(R.id.ll_priority_bg, "setBackgroundResource", R.drawable.bg_priority_high)
                
                views.setImageViewResource(R.id.iv_priority_icon, R.drawable.ic_priority_high_img)
                views.setViewVisibility(R.id.iv_priority_icon, android.view.View.VISIBLE)
            }
            "medium" -> {
                views.setTextViewText(R.id.tv_priority, "! Medium Priority")
                views.setTextColor(R.id.tv_priority, Color.parseColor("#D97706")) 
                views.setInt(R.id.ll_priority_bg, "setBackgroundResource", R.drawable.bg_priority_medium)
                
                views.setViewVisibility(R.id.iv_priority_icon, android.view.View.GONE)
            }
            else -> {
                views.setTextViewText(R.id.tv_priority, "Low Priority")
                views.setTextColor(R.id.tv_priority, Color.parseColor("#27AE60")) 
                views.setInt(R.id.ll_priority_bg, "setBackgroundResource", R.drawable.bg_priority_low)
                
                views.setImageViewResource(R.id.iv_priority_icon, R.drawable.ic_priority_low_img)
                views.setViewVisibility(R.id.iv_priority_icon, android.view.View.VISIBLE)
            }
        }
        
        if (task.isTeam) {
            views.setViewVisibility(R.id.tv_team_tag, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.tv_team_tag, android.view.View.GONE)
        }
        
        if (task.isCompleted) {
            views.setImageViewResource(R.id.btn_checkbox, R.drawable.ic_checkbox_checked)
            views.setInt(R.id.tv_task_title, "setPaintFlags", 16)
            views.setTextColor(R.id.tv_task_title, Color.parseColor("#B0A495"))
        } else {
            views.setImageViewResource(R.id.btn_checkbox, R.drawable.ic_checkbox_outline)
            views.setInt(R.id.tv_task_title, "setPaintFlags", 0)
            views.setTextColor(R.id.tv_task_title, Color.parseColor("#3A3042"))
        }

        val detailFillInIntent = android.content.Intent().apply {
            data = android.net.Uri.parse("wudi-widget://task-detail?id=${task.id}&isTeam=${task.isTeam}&team_id=${task.teamId}")
        }

        views.setFloat(R.id.btn_checkbox, "setAlpha", if (task.isLocked) 0.45f else 1.0f)
        views.setOnClickFillInIntent(R.id.ll_priority_bg, detailFillInIntent)
        views.setOnClickFillInIntent(R.id.tv_task_title, detailFillInIntent)
        views.setOnClickFillInIntent(R.id.tv_task_time, detailFillInIntent)

        val toggleFillInIntent = Intent().apply {
            data = android.net.Uri.parse("wudi-widget://toggle-task?id=${task.id}&widget_key=${android.net.Uri.encode(task.widgetKey)}&isTeam=${task.isTeam}&team_id=${task.teamId}")
        }
        views.setOnClickFillInIntent(R.id.btn_checkbox, toggleFillInIntent)
        
        return views
    }

    override fun onDestroy() {}
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = tasks[position].widgetKey.hashCode().toLong()
    override fun hasStableIds(): Boolean = true
}
