package com.syameimarukoa.fs050w_signal_display

import android.content.Context
import android.graphics.text.TextRunShaper
import android.os.Build
import android.widget.TextView
import androidx.annotation.RequiresApi
import java.security.MessageDigest

/** Read the fonts selected by Android, including OEM system font settings. */
object SystemFontProvider {
    fun read(context: Context, previousSignature: String?): Map<String, Any>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return readSupported(context, previousSignature)
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun readSupported(context: Context, previousSignature: String?): Map<String, Any>? {
        val paint = TextView(context).paint
        // Latin first, then Japanese scripts used throughout the application.
        val sample = "Aa0123456789あア漢電波強度品質接続設定温℃"
        val glyphs = TextRunShaper.shapeTextRun(
            sample, 0, sample.length, 0, sample.length, 0f, 0f, false, paint
        )
        val fonts = (0 until glyphs.glyphCount()).map { glyphs.getFont(it) }.distinct()
        val digest = MessageDigest.getInstance("SHA-256")
        val entries = fonts.map { font ->
            val buffer = font.buffer.duplicate().apply { clear() }
            val bytes = ByteArray(buffer.remaining())
            buffer.get(bytes)
            digest.update(bytes)
            digest.update(font.ttcIndex.toString().toByteArray(Charsets.UTF_8))
            mapOf<String, Any>("bytes" to bytes, "ttcIndex" to font.ttcIndex)
        }
        val signature = digest.digest().joinToString("") { "%02x".format(it) }
        if (signature == previousSignature || entries.isEmpty()) return null
        return mapOf("signature" to signature, "fonts" to entries)
    }
}
