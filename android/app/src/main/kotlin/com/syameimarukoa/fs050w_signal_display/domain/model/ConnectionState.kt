package com.syameimarukoa.fs050w_signal_display.domain.model

/** 4G/5G connection modes reported by the router. */
enum class Fs050wConnectionMode {
    LTE,
    NSA_READY,
    NR5G,
    NR5G_SUB6,
    DISCONNECTED,
}

object ConnectionModeHelper {
    fun getIconBadgeText(mode: Fs050wConnectionMode, notation: String = "4g_5g"): String {
        val isLteNr = notation == "lte_nr"
        return when (mode) {
            Fs050wConnectionMode.LTE -> if (isLteNr) "LTE" else "4G"
            Fs050wConnectionMode.NSA_READY -> if (isLteNr) "eLTE" else "e4G"
            Fs050wConnectionMode.NR5G -> if (isLteNr) "NR" else "5G"
            Fs050wConnectionMode.NR5G_SUB6 -> if (isLteNr) "NR+" else "5G+"
            Fs050wConnectionMode.DISCONNECTED -> "--"
        }
    }

    fun getUiModeText(mode: Fs050wConnectionMode, isSa: Boolean = false, notation: String = "4g_5g"): String {
        val isLteNr = notation == "lte_nr"
        return when (mode) {
            Fs050wConnectionMode.LTE -> if (isLteNr) "LTE" else "4G"
            Fs050wConnectionMode.NSA_READY -> if (isLteNr) "eLTE" else "e4G"
            Fs050wConnectionMode.NR5G -> {
                val label = if (isLteNr) "NR" else "5G"
                if (isSa) "$label SA" else label
            }
            Fs050wConnectionMode.NR5G_SUB6 -> {
                val label = if (isLteNr) "NR+" else "5G+"
                if (isSa) "$label SA" else label
            }
            Fs050wConnectionMode.DISCONNECTED -> "未接続"
        }
    }

    fun get4gCardTitle(mode: Fs050wConnectionMode, notation: String = "4g_5g"): String {
        val isLteNr = notation == "lte_nr"
        return when (mode) {
            Fs050wConnectionMode.LTE -> if (isLteNr) "LTE" else "4G"
            Fs050wConnectionMode.NSA_READY,
            Fs050wConnectionMode.NR5G,
            Fs050wConnectionMode.NR5G_SUB6 -> if (isLteNr) "LTE Anchor Cell" else "4G Anchor Cell"
            Fs050wConnectionMode.DISCONNECTED -> if (isLteNr) "LTE (未接続)" else "4G (未接続)"
        }
    }

    fun get5gCardTitle(mode: Fs050wConnectionMode, notation: String = "4g_5g"): String {
        val isLteNr = notation == "lte_nr"
        return when (mode) {
            Fs050wConnectionMode.NR5G_SUB6 -> if (isLteNr) "NR+ (sub6)" else "5G+ (sub6)"
            Fs050wConnectionMode.NR5G -> if (isLteNr) "NR" else "5G"
            Fs050wConnectionMode.NSA_READY -> if (isLteNr) "NR (待機中)" else "5G (待機中)"
            else -> if (isLteNr) "NR" else "5G"
        }
    }

    fun getGenerationName(is5g: Boolean, notation: String = "4g_5g"): String {
        val isLteNr = notation == "lte_nr"
        return if (is5g) (if (isLteNr) "NR" else "5G") else (if (isLteNr) "LTE" else "4G")
    }
}
