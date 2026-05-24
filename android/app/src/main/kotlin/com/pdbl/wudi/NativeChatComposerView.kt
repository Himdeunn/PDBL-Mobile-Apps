package com.pdbl.wudi

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class NativeChatComposerView(
    private val context: Context,
    id: Int,
    params: Map<String, Any?>,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val editText = EditText(context)
    private val channel = MethodChannel(messenger, "wudi/native_chat_composer/$id")
    private var updatingFromFlutter = false

    init {
        val textColor = (params["textColor"] as? Number)?.toInt() ?: Color.rgb(31, 41, 55)
        val hintColor = (params["hintColor"] as? Number)?.toInt() ?: Color.rgb(107, 114, 128)
        val accentColor = (params["accentColor"] as? Number)?.toInt() ?: Color.rgb(99, 46, 94)
        val selectionColor = (params["selectionColor"] as? Number)?.toInt() ?: Color.argb(66, 128, 90, 213)

        editText.setText(params["text"] as? String ?: "")
        editText.hint = params["hint"] as? String ?: "Type a message"
        editText.isEnabled = params["enabled"] as? Boolean ?: true
        editText.setTextColor(textColor)
        editText.setHintTextColor(hintColor)
        editText.highlightColor = selectionColor
        tintTextSelectionDrawables(accentColor)
        editText.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
        editText.gravity = Gravity.CENTER_VERTICAL or Gravity.START
        editText.minLines = 1
        editText.maxLines = 5
        editText.isVerticalScrollBarEnabled = true
        editText.setSingleLine(false)
        editText.inputType = InputType.TYPE_CLASS_TEXT or
            InputType.TYPE_TEXT_FLAG_MULTI_LINE or
            InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        editText.setPadding(dp(16), dp(8), dp(16), dp(8))
        editText.background = GradientDrawable().apply {
            setColor(Color.TRANSPARENT)
            cornerRadius = dp(22).toFloat()
        }
        editText.includeFontPadding = false
        editText.setSelectAllOnFocus(false)

        editText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) = Unit
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) = Unit

            override fun afterTextChanged(s: Editable?) {
                if (updatingFromFlutter) return
                channel.invokeMethod(
                    "onChanged",
                    mapOf(
                        "text" to editText.text.toString(),
                        "selection" to editText.selectionStart.coerceAtLeast(0),
                    ),
                )
            }
        })

        channel.setMethodCallHandler(this)
    }

    override fun getView(): View = editText

    override fun dispose() {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setText" -> {
                setText(call.arguments as? String ?: "")
                result.success(null)
            }
            "setEnabled" -> {
                editText.isEnabled = call.arguments as? Boolean ?: true
                result.success(null)
            }
            "setHint" -> {
                editText.hint = call.arguments as? String ?: "Type a message"
                result.success(null)
            }
            "requestFocus" -> {
                editText.requestFocus()
                editText.post {
                    val imm = context.getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
                    imm.showSoftInput(editText, InputMethodManager.SHOW_IMPLICIT)
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun setText(text: String) {
        if (editText.text.toString() == text) return
        updatingFromFlutter = true
        editText.setText(text)
        editText.setSelection(text.length)
        updatingFromFlutter = false
    }

    private fun dp(value: Int): Int = (value * context.resources.displayMetrics.density).toInt()

    private fun tintTextSelectionDrawables(color: Int) {
        editText.textCursorDrawable = tinted(editText.textCursorDrawable, color)
        defaultHandle("text_select_handle_middle", editText.textSelectHandle, color)?.let {
            editText.setTextSelectHandle(it)
        }
        defaultHandle("text_select_handle_left", editText.textSelectHandleLeft, color)?.let {
            editText.setTextSelectHandleLeft(it)
        }
        defaultHandle("text_select_handle_right", editText.textSelectHandleRight, color)?.let {
            editText.setTextSelectHandleRight(it)
        }
    }

    private fun tinted(drawable: Drawable?, color: Int): Drawable? {
        return drawable?.mutate()?.apply { setTint(color) }
    }

    private fun defaultHandle(name: String, fallback: Drawable?, color: Int): Drawable? {
        val resourceId = context.resources.getIdentifier(name, "drawable", "android")
        val drawable = if (resourceId != 0) context.getDrawable(resourceId) else fallback
        return tinted(drawable, color)
    }
}
