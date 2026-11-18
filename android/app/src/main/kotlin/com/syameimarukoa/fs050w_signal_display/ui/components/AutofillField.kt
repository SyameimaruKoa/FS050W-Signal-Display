package com.syameimarukoa.fs050w_signal_display.ui.components

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.text.InputType
import android.text.method.PasswordTransformationMethod
import android.view.autofill.AutofillManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.toArgb
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView

/**
 * Material-styled [EditText] that forwards Android autofill hints.
 *
 * Flutter 版は AutofillGroup の中で
 *   - IP 欄: [AutofillHints.url, AutofillHints.username]
 *   - パスワード欄: [AutofillHints.password]
 * を指定し、onEditingComplete で finishAutofillContext(shouldSave: true) を呼んでいた。
 * Compose の Modifier.contentType() は FillRequest の hints に反映されないため、
 * 素の EditText に autofillHints を明示設定して Flutter 版と同じ挙動を実現する。
 */
@Composable
fun AutofillField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    hints: Array<String>,
    password: Boolean = false,
    passwordVisible: Boolean = false,
    imeDone: Boolean = false,
    onDone: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val outline = MaterialTheme.colorScheme.outline.toArgb()
    val onSurface = MaterialTheme.colorScheme.onSurface.toArgb()
    val surface = MaterialTheme.colorScheme.surface.toArgb()
    val density = context.resources.displayMetrics.density
    val pad = (14 * density).toInt()

    AndroidView(
        factory = { ctx: Context ->
            EditText(ctx).apply {
                setAutofillHints(*hints)
                this.hint = label
                inputType = if (password) {
                    InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                } else {
                    InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                }
                transformationMethod = if (password && !passwordVisible) PasswordTransformationMethod.getInstance() else null
                setTextColor(onSurface)
                setHintTextColor(onSurface)
                textSize = 16f
                imeOptions = if (imeDone) EditorInfo.IME_ACTION_DONE else EditorInfo.IME_ACTION_NEXT
                isSingleLine = true
                setPadding(pad, pad, pad, pad)
                background = GradientDrawable().apply {
                    cornerRadius = 8 * density
                    setStroke(1, outline)
                    setColor(surface)
                }
                addTextChangedListener(object : android.text.TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: android.text.Editable?) {
                        onValueChange(s?.toString().orEmpty())
                    }
                })
                setOnEditorActionListener { _, actionId, _ ->
                    if (actionId == EditorInfo.IME_ACTION_DONE) {
                        try {
                            context.getSystemService(AutofillManager::class.java)?.commit()
                        } catch (_: Exception) {
                        }
                        onDone()
                        true
                    } else false
                }
            }
        },
        update = { editText ->
            if (editText.text?.toString() != value) {
                editText.setText(value)
            }
            if (password) {
                val shouldMask = !passwordVisible
                val isMasked = editText.transformationMethod is PasswordTransformationMethod
                if (shouldMask != isMasked) {
                    editText.transformationMethod =
                        if (shouldMask) PasswordTransformationMethod.getInstance() else null
                }
            }
        },
        modifier = modifier.fillMaxWidth(),
    )
}
