package com.pdbl.wudi

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.Drawable
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.InputFilter
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class NativeTextInputView(
    private val context: Context,
    id: Int,
    params: Map<String, Any?>,
    messenger: io.flutter.plugin.common.BinaryMessenger,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val editText = EditText(context)
    private val channel = MethodChannel(messenger, "wudi/native_text_input/$id")
    private var updatingFromFlutter = false

    init {
        configure(params)
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
        editText.setOnEditorActionListener { _, actionId, _ ->
            if (actionId != EditorInfo.IME_ACTION_NONE) {
                channel.invokeMethod("onSubmitted", editText.text.toString())
                true
            } else {
                false
            }
        }
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
                editText.hint = call.arguments as? String ?: ""
                result.success(null)
            }
            "setObscureText" -> {
                updateInputType(call.arguments as? Boolean ?: false, null)
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

    private fun configure(params: Map<String, Any?>) {
        val textColor = (params["textColor"] as? Number)?.toInt() ?: Color.rgb(26, 26, 26)
        val hintColor = (params["hintColor"] as? Number)?.toInt() ?: Color.rgb(153, 153, 153)
        val accentColor = (params["accentColor"] as? Number)?.toInt() ?: Color.rgb(99, 46, 94)
        val selectionColor = (params["selectionColor"] as? Number)?.toInt() ?: Color.argb(66, 99, 46, 94)
        val minLines = (params["minLines"] as? Number)?.toInt() ?: 1
        val maxLines = (params["maxLines"] as? Number)?.toInt() ?: 1

        editText.setText(params["text"] as? String ?: "")
        editText.hint = params["hint"] as? String ?: ""
        editText.isEnabled = params["enabled"] as? Boolean ?: true
        editText.setTextColor(textColor)
        editText.setHintTextColor(hintColor)
        editText.highlightColor = selectionColor
        editText.setTextSize(android.util.TypedValue.COMPLEX_UNIT_SP, (params["textSize"] as? Number)?.toFloat() ?: 14f)
        editText.gravity = if (maxLines > 1) Gravity.TOP or Gravity.START else Gravity.CENTER_VERTICAL or Gravity.START
        editText.gravity = editText.gravityFor(params["textAlign"]?.toString(), maxLines)
        editText.minLines = minLines
        editText.maxLines = maxLines
        editText.filters = (params["maxLength"] as? Number)?.toInt()?.let {
            arrayOf<InputFilter>(InputFilter.LengthFilter(it))
        } ?: emptyArray()
        editText.setSingleLine(maxLines == 1)
        editText.setPadding(
            dp(params["paddingLeft"]),
            dp(params["paddingTop"]),
            dp(params["paddingRight"]),
            dp(params["paddingBottom"]),
        )
        editText.background = GradientDrawable().apply { setColor(Color.TRANSPARENT) }
        editText.includeFontPadding = true
        editText.setSelectAllOnFocus(false)
        tintTextSelectionDrawables(accentColor)
        updateInputType(params["obscureText"] as? Boolean ?: false, params["keyboardType"]?.toString())
        editText.imeOptions = inputAction(params["textInputAction"]?.toString())
    }

    private fun updateInputType(obscureText: Boolean, keyboardType: String?) {
        val baseType = when (keyboardType) {
            "email" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
            "number" -> InputType.TYPE_CLASS_NUMBER
            "phone" -> InputType.TYPE_CLASS_PHONE
            "multiline" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            "visiblePassword" -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
            else -> InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
        }
        editText.inputType = if (obscureText) {
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
        } else {
            baseType
        }
        editText.setSelection(editText.text.length)
    }

    private fun EditText.gravityFor(textAlign: String?, maxLines: Int): Int {
        val vertical = if (maxLines > 1) Gravity.TOP else Gravity.CENTER_VERTICAL
        val horizontal = when (textAlign) {
            "center" -> Gravity.CENTER_HORIZONTAL
            "end" -> Gravity.END
            else -> Gravity.START
        }
        return vertical or horizontal
    }

    private fun inputAction(action: String?): Int = when (action) {
        "search" -> EditorInfo.IME_ACTION_SEARCH
        "send" -> EditorInfo.IME_ACTION_SEND
        "next" -> EditorInfo.IME_ACTION_NEXT
        "newline" -> EditorInfo.IME_ACTION_NONE
        else -> EditorInfo.IME_ACTION_DONE
    }

    private fun setText(text: String) {
        if (editText.text.toString() == text) return
        updatingFromFlutter = true
        editText.setText(text)
        editText.setSelection(text.length)
        updatingFromFlutter = false
    }

    private fun dp(value: Any?): Int = ((value as? Number)?.toFloat() ?: 0f)
        .let { (it * context.resources.displayMetrics.density).toInt() }

    private fun tintTextSelectionDrawables(color: Int) {
        editText.textCursorDrawable = tinted(editText.textCursorDrawable, color)
        tinted(editText.textSelectHandle, color)?.let { editText.setTextSelectHandle(it) }
        tinted(editText.textSelectHandleLeft, color)?.let { editText.setTextSelectHandleLeft(it) }
        tinted(editText.textSelectHandleRight, color)?.let { editText.setTextSelectHandleRight(it) }
    }

    private fun tinted(drawable: Drawable?, color: Int): Drawable? {
        return drawable?.mutate()?.apply { setTint(color) }
    }
}
