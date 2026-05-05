package com.pdbl.wudi

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class MainActivity : FlutterActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        HomeWidgetLaunchIntent.setLaunchIntent(intent)
    }
}
