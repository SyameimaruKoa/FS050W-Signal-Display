package com.syameimarukoa.fs050w_signal_display.domain.util

import com.syameimarukoa.fs050w_signal_display.domain.model.SignalRatingLevel
import kotlin.math.pow
import kotlin.math.roundToInt

/**
 * Single source of truth for signal colouring. Colours are 0xAARRGGBB packed in a Long
 * so that this object stays pure Kotlin and unit-testable without Android classes.
 */
object ColorGauge {
    const val COLOR_EXCELLENT: Long = 0xFF2196F3
    const val COLOR_GOOD: Long = 0xFF4CAF50
    const val COLOR_MODERATE: Long = 0xFF8BC34A
    const val COLOR_WEAK: Long = 0xFFFF9800
    const val COLOR_VERY_WEAK: Long = 0xFFF44336L
    const val COLOR_CRITICAL: Long = 0xFF9C27B0
    const val COLOR_UNKNOWN: Long = 0xFF757575

    const val RSRP_MIN = -120.0
    const val RSRP_MAX = -70.0
    const val RSRQ_MIN = -22.0
    const val RSRQ_MAX = -3.0
    const val SINR_MIN = -6.0
    const val SINR_MAX = 24.0

    data class MetricThreshold(
        val value: Double,
        val level: SignalRatingLevel,
        val color: Long,
        val label: String,
    )

    val rsrpThresholds = listOf(
        MetricThreshold(-80.0, SignalRatingLevel.EXCELLENT, COLOR_EXCELLENT, "極めて優秀"),
        MetricThreshold(-90.0, SignalRatingLevel.GOOD, COLOR_GOOD, "良好"),
        MetricThreshold(-100.0, SignalRatingLevel.MODERATE, COLOR_MODERATE, "普通"),
        MetricThreshold(-110.0, SignalRatingLevel.WEAK, COLOR_WEAK, "微弱"),
        MetricThreshold(-120.0, SignalRatingLevel.VERY_WEAK, COLOR_VERY_WEAK, "極めて微弱"),
    )
    val rsrqThresholds = listOf(
        MetricThreshold(-10.0, SignalRatingLevel.EXCELLENT, COLOR_EXCELLENT, "極めて優秀"),
        MetricThreshold(-15.0, SignalRatingLevel.GOOD, COLOR_GOOD, "良好"),
        MetricThreshold(-18.0, SignalRatingLevel.MODERATE, COLOR_MODERATE, "普通"),
        MetricThreshold(-20.0, SignalRatingLevel.WEAK, COLOR_WEAK, "微弱"),
        MetricThreshold(-22.0, SignalRatingLevel.VERY_WEAK, COLOR_VERY_WEAK, "極めて微弱"),
    )
    val sinrThresholds = listOf(
        MetricThreshold(20.0, SignalRatingLevel.EXCELLENT, COLOR_EXCELLENT, "極めて優秀"),
        MetricThreshold(13.0, SignalRatingLevel.GOOD, COLOR_GOOD, "良好"),
        MetricThreshold(0.0, SignalRatingLevel.MODERATE, COLOR_MODERATE, "普通"),
        MetricThreshold(-3.0, SignalRatingLevel.WEAK, COLOR_WEAK, "微弱"),
        MetricThreshold(-6.0, SignalRatingLevel.VERY_WEAK, COLOR_VERY_WEAK, "極めて微弱"),
    )

    fun temperatureColor(temperature: Double?, threshold: Double = 45.0): Long {
        if (temperature == null || !temperature.isFinite()) return COLOR_UNKNOWN
        if (temperature >= threshold) return 0xFFFF5252
        if (temperature >= threshold - 5.0) return 0xFFFFD600
        return 0xFF00E5FF
    }

    fun latencyColor(milliseconds: Int?): Long {
        if (milliseconds == null) return COLOR_UNKNOWN
        if (milliseconds <= 50) return 0xFF00E676
        if (milliseconds <= 150) return 0xFFFFD600
        return 0xFFFF5252
    }

    fun rateRsrp(rsrp: Double?): SignalRatingLevel {
        if (rsrp == null || !rsrp.isFinite() || rsrp <= -200) return SignalRatingLevel.UNKNOWN
        return when {
            rsrp >= -80.0 -> SignalRatingLevel.EXCELLENT
            rsrp >= -90.0 -> SignalRatingLevel.GOOD
            rsrp >= -100.0 -> SignalRatingLevel.MODERATE
            rsrp >= -110.0 -> SignalRatingLevel.WEAK
            rsrp >= -120.0 -> SignalRatingLevel.VERY_WEAK
            else -> SignalRatingLevel.CRITICAL
        }
    }

    fun rateRsrq(rsrq: Double?): SignalRatingLevel {
        if (rsrq == null || !rsrq.isFinite() || rsrq <= -200) return SignalRatingLevel.UNKNOWN
        return when {
            rsrq >= -10.0 -> SignalRatingLevel.EXCELLENT
            rsrq >= -15.0 -> SignalRatingLevel.GOOD
            rsrq >= -18.0 -> SignalRatingLevel.MODERATE
            rsrq >= -20.0 -> SignalRatingLevel.WEAK
            rsrq >= -22.0 -> SignalRatingLevel.VERY_WEAK
            else -> SignalRatingLevel.CRITICAL
        }
    }

    fun rateSinr(sinr: Double?): SignalRatingLevel {
        if (sinr == null || !sinr.isFinite() || sinr <= -200) return SignalRatingLevel.UNKNOWN
        return when {
            sinr >= 20.0 -> SignalRatingLevel.EXCELLENT
            sinr >= 13.0 -> SignalRatingLevel.GOOD
            sinr >= 0.0 -> SignalRatingLevel.MODERATE
            sinr >= -3.0 -> SignalRatingLevel.WEAK
            sinr >= -6.0 -> SignalRatingLevel.VERY_WEAK
            else -> SignalRatingLevel.CRITICAL
        }
    }

    fun colorFor(level: SignalRatingLevel): Long = when (level) {
        SignalRatingLevel.EXCELLENT -> COLOR_EXCELLENT
        SignalRatingLevel.GOOD -> COLOR_GOOD
        SignalRatingLevel.MODERATE -> COLOR_MODERATE
        SignalRatingLevel.WEAK -> COLOR_WEAK
        SignalRatingLevel.VERY_WEAK -> COLOR_VERY_WEAK
        SignalRatingLevel.CRITICAL -> COLOR_CRITICAL
        SignalRatingLevel.UNKNOWN -> COLOR_UNKNOWN
    }

    fun metricColor(
        value: Double?,
        level: SignalRatingLevel,
        min: Double,
        max: Double,
        smooth: Boolean = false,
        curve: String = "easeOut",
    ): Long {
        if (value == null || !value.isFinite() || value <= -200) return COLOR_UNKNOWN
        return if (smooth) {
            getSmoothColor(((value - min) / (max - min)).coerceIn(0.0, 1.0), curve)
        } else {
            colorFor(level)
        }
    }

    fun applyCurve(ratio: Double, curveType: String): Double {
        val r = ratio.coerceIn(0.0, 1.0)
        return when (curveType) {
            "easeOut" -> 1.0 - (1.0 - r).pow(2.0)
            "easeIn" -> r.pow(2.0)
            "easeInOut" -> if (r < 0.5) 2.0 * r * r else 1.0 - (-2.0 * r + 2.0).pow(2.0) / 2.0
            else -> r
        }
    }

    fun getSmoothColor(ratio: Double, curve: String = "linear"): Long {
        val r = applyCurve(ratio, curve).coerceIn(0.0, 1.0)
        return when {
            r < 0.20 -> lerp(COLOR_CRITICAL, COLOR_VERY_WEAK, r / 0.20)
            r < 0.40 -> lerp(COLOR_VERY_WEAK, COLOR_WEAK, (r - 0.20) / 0.20)
            r < 0.60 -> lerp(COLOR_WEAK, COLOR_MODERATE, (r - 0.40) / 0.20)
            r < 0.80 -> lerp(COLOR_MODERATE, COLOR_GOOD, (r - 0.60) / 0.20)
            else -> lerp(COLOR_GOOD, COLOR_EXCELLENT, (r - 0.80) / 0.20)
        }
    }

    fun calculateNormalizedRatio(value: Double?, min: Double, max: Double, curve: String = "linear"): Double {
        if (value == null || value.isNaN()) return 0.0
        return applyCurve(((value - min) / (max - min)).coerceIn(0.0, 1.0), curve)
    }

    fun getLabel(level: SignalRatingLevel): String = when (level) {
        SignalRatingLevel.EXCELLENT -> "極めて優秀"
        SignalRatingLevel.GOOD -> "良好"
        SignalRatingLevel.MODERATE -> "普通"
        SignalRatingLevel.WEAK -> "微弱"
        SignalRatingLevel.VERY_WEAK -> "極めて微弱"
        SignalRatingLevel.CRITICAL -> "限界 / 圏外寸前"
        SignalRatingLevel.UNKNOWN -> "未取得"
    }

    fun getProgress(level: SignalRatingLevel): Double = when (level) {
        SignalRatingLevel.EXCELLENT -> 1.0
        SignalRatingLevel.GOOD -> 0.83
        SignalRatingLevel.MODERATE -> 0.66
        SignalRatingLevel.WEAK -> 0.50
        SignalRatingLevel.VERY_WEAK -> 0.33
        SignalRatingLevel.CRITICAL -> 0.16
        SignalRatingLevel.UNKNOWN -> 0.0
    }

    private fun lerp(a: Long, b: Long, t: Double): Long {
        val ar = (a shr 16) and 0xFF
        val ag = (a shr 8) and 0xFF
        val ab = a and 0xFF
        val br = (b shr 16) and 0xFF
        val bg = (b shr 8) and 0xFF
        val bb = b and 0xFF
        val r = (ar + (br - ar) * t).roundToInt().coerceIn(0, 255)
        val g = (ag + (bg - ag) * t).roundToInt().coerceIn(0, 255)
        val bl = (ab + (bb - ab) * t).roundToInt().coerceIn(0, 255)
        return 0xFF000000L or (r.toLong() shl 16) or (g.toLong() shl 8) or bl.toLong()
    }
}
