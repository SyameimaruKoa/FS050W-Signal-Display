package com.syameimarukoa.fs050w_signal_display.ui.components

import android.content.Context
import android.graphics.drawable.GradientDrawable
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.text.method.PasswordTransformationMethod
import android.view.View
import android.view.autofill.AutofillManager
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.LinearLayout
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView

/**
 * Flutter 版 AutofillGroup のネイティブ等価実装。
 *
 * IP 欄とパスワード欄を **1 つの ViewGroup (LinearLayout)** に格納する。
 * 標準の ViewGroup.onProvideAutofillStructure() は子ビューを同じ ViewStructure
 * （= 同じ FillContext）へ再帰的に追加するため、パスワード欄フォーカス時に
 * IP 欄の `url` ヒントも Autofill サービスへ届く。
 *
 * Flutter は TextInputConfiguration.toJson()['fields'] に両フィールドを入れて
 * 同じ効果を実現していた（_AutofillScopeTextInputConfiguration）。
 */
@Composable
fun AutofillCredentialFields(
    ip: String,
    password: String,
    onIpChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    ipLabel: String = "ルーターIPアドレス",
    passwordLabel: String = "Web管理パスワード",
    passwordVisible: Boolean = false,
    onDone: () -> Unit = {},
) {
    val context = LocalContext.current
    val outline = MaterialTheme.colorScheme.outline.toArgb()
    val onSurface = MaterialTheme.colorScheme.onSurface.toArgb()
    val surface = MaterialTheme.colorScheme.surface.toArgb()
    val density = context.resources.displayMetrics.density
    val pad = (14 * density).toInt()
    val gap = (16 * density).toInt()

    AndroidView(
        factory = { ctx: Context ->
            LinearLayout(ctx).apply {
                orientation = LinearLayout.VERTICAL

                val ipEdit = EditText(ctx).apply {
                    setAutofillHints("url", View.AUTOFILL_HINT_USERNAME)
                    hint = ipLabel
                    inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
                    setTextColor(onSurface)
                    setHintTextColor(onSurface)
                    textSize = 16f
                    isSingleLine = true
                    imeOptions = EditorInfo.IME_ACTION_NEXT
                    setPadding(pad, pad, pad, pad)
                    background = boxBackground(outline, surface, density)
                    setText(ip)
                    addWatcher { onIpChange(it) }
                }

                val passEdit = EditText(ctx).apply {
                    setAutofillHints(View.AUTOFILL_HINT_PASSWORD)
                    hint = passwordLabel
                    inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
                    transformationMethod = if (passwordVisible) null else PasswordTransformationMethod.getInstance()
                    setTextColor(onSurface)
                    setHintTextColor(onSurface)
                    textSize = 16f
                    isSingleLine = true
                    imeOptions = EditorInfo.IME_ACTION_DONE
                    setPadding(pad, pad, pad, pad)
                    background = boxBackground(outline, surface, density)
                    setText(password)
                    addWatcher { onPasswordChange(it) }
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

                addView(ipEdit, LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ))
                addView(passEdit, LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                ).apply { topMargin = gap })

                tag = FormViews(ipEdit, passEdit)
            }
        },
        update = { group ->
            val views = group.tag as? FormViews ?: return@AndroidView
            if (views.ip.text?.toString() != ip) views.ip.setText(ip)
            if (views.password.text?.toString() != password) views.password.setText(password)
            val masked = views.password.transformationMethod is PasswordTransformationMethod
            val shouldMask = !passwordVisible
            if (masked != shouldMask) {
                views.password.transformationMethod =
                    if (shouldMask) PasswordTransformationMethod.getInstance() else null
            }
        },
    )
}

private data class FormViews(val ip: EditText, val password: EditText)

private fun boxBackground(outline: Int, surface: Int, density: Float): GradientDrawable =
    GradientDrawable().apply {
        cornerRadius = 8 * density
        setStroke(1, outline)
        setColor(surface)
    }

private fun EditText.addWatcher(onChange: (String) -> Unit) {
    addTextChangedListener(object : TextWatcher {
        override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
        override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
        override fun afterTextChanged(s: Editable?) = onChange(s?.toString().orEmpty())
    })
}
