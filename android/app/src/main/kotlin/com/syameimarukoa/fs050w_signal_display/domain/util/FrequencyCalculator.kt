package com.syameimarukoa.fs050w_signal_display.domain.util

object FrequencyCalculator {
    fun getLteBandName(band: Int?): String {
        if (band == null || band <= 0) return "--"
        return when (band) {
            1 -> "B1 (2.1GHz)"
            3 -> "B3 (1.7GHz)"
            8 -> "B8 (900MHz)"
            11 -> "B11 (1.5GHz)"
            18 -> "B18 (800MHz)"
            19 -> "B19 (800MHz)"
            21 -> "B21 (1.5GHz)"
            26 -> "B26 (800MHz)"
            28 -> "B28 (700MHz)"
            41 -> "B41 (2.5GHz)"
            42 -> "B42 (3.5GHz)"
            else -> "B$band"
        }
    }

    fun getLteBadgeText(band: Int?, operatorName: String?): String? {
        if (band == null || band <= 0) return null
        val op = (operatorName ?: "").lowercase().replace(" ", "")
        val isRakuten = op.contains("rakuten") || op.contains("楽天") || op.contains("44011") || op.contains("44053")
        if (isRakuten) {
            when (band) {
                3 -> return "楽天回線"
                18, 26 -> return "ローミング"
                28 -> return "プラチナ"
            }
        }
        return when (band) {
            8, 18, 19, 26, 28 -> "プラチナ"
            41, 42 -> "TDD"
            1, 3, 11, 21 -> "FDD"
            else -> null
        }
    }

    fun getNrBandName(band: Int?): String {
        if (band == null || band <= 0) return "--"
        return when (band) {
            77 -> "n77 (3.8GHz)"
            78 -> "n78 (3.7GHz)"
            79 -> "n79 (4.5GHz)"
            28 -> "n28 (700MHz)"
            3 -> "n3 (1.7GHz)"
            1 -> "n1 (2.1GHz)"
            else -> "n$band"
        }
    }

    fun getNrBadgeText(band: Int?): String? {
        if (band == null || band <= 0) return null
        if (isSub6Band(band)) return "Sub6"
        if (isRefarmed5gBand(band)) return "転用5G"
        return null
    }

    fun isSub6Band(band: Int?): Boolean = band == 77 || band == 78 || band == 79

    fun isRefarmed5gBand(band: Int?): Boolean = band == 1 || band == 3 || band == 28
}
