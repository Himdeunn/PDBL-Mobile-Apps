package com.pdbl.wudi

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "wudi/native_chat_composer",
            NativeChatComposerFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "wudi/native_text_input",
            NativeTextInputFactory(flutterEngine.dartExecutor.binaryMessenger),
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}
