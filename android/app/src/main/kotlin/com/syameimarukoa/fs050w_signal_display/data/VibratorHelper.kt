package com.syameimarukoa.fs050w_signal_display.data

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

object VibratorHelper {
    fun vibrate(context: Context, type: String) {
        try {
            val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
            if (vibrator == null || !vibrator.hasVibrator()) return

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = when (type) {
                    "5g" -> VibrationEffect.createWaveform(longArrayOf(0, 70, 60, 70), intArrayOf(0, 255, 0, 255), -1)
                    "handover" -> VibrationEffect.createOneShot(80, 180)
                    "critical" -> VibrationEffect.createWaveform(longArrayOf(0, 150, 100, 150), intArrayOf(0, 255, 0, 255), -1)
                    "battery_temp" -> VibrationEffect.createWaveform(
                        longArrayOf(0, 200, 100, 200, 100, 200),
                        intArrayOf(0, 255, 0, 255, 0, 255),
                        -1,
                    )
                    else -> VibrationEffect.createOneShot(60, VibrationEffect.DEFAULT_AMPLITUDE)
                }
                vibrator.vibrate(effect)
            } else {
                @Suppress("DEPRECATION")
                when (type) {
                    "5g" -> vibrator.vibrate(longArrayOf(0, 70, 60, 70), -1)
                    "handover" -> vibrator.vibrate(80)
                    "critical" -> vibrator.vibrate(longArrayOf(0, 150, 100, 150), -1)
                    "battery_temp" -> vibrator.vibrate(longArrayOf(0, 200, 100, 200, 100, 200), -1)
                    else -> vibrator.vibrate(60)
                }
            }
        } catch (e: Exception) {
            AppLogger.warn("Vibration failed: ${e.message}")
        }
    }
}
