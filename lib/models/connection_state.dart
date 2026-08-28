enum Fs050wConnectionMode {
    lte,           // ① 4G LTE -> [4G] / [LTE]
    nsaReady,      // ② 4G Ready (5G NSA待機) -> [e4G] / [eLTE]
    nr5g,          // ③ 5G NR (転用/通常5G/SA) -> [5G] / [NR]
    nr5gSub6,      // ④ 5G+ NR+ (sub6高速5G/SA) -> [5G+] / [NR+]
    disconnected,  // 未接続
}

class ConnectionModeHelper {
    static String getIconBadgeText(Fs050wConnectionMode mode, {String notation = "4g_5g"}) {
        final isLteNr = notation == "lte_nr";
        switch (mode) {
            case Fs050wConnectionMode.lte:
                return isLteNr ? "LTE" : "4G";
            case Fs050wConnectionMode.nsaReady:
                return isLteNr ? "eLTE" : "e4G";
            case Fs050wConnectionMode.nr5g:
                return isLteNr ? "NR" : "5G";
            case Fs050wConnectionMode.nr5gSub6:
                return isLteNr ? "NR+" : "5G+";
            case Fs050wConnectionMode.disconnected:
                return "--";
        }
    }

    static String getUiModeText(Fs050wConnectionMode mode, {bool isSa = false, String notation = "4g_5g"}) {
        final isLteNr = notation == "lte_nr";
        switch (mode) {
            case Fs050wConnectionMode.lte:
                return isLteNr ? "LTE" : "4G";
            case Fs050wConnectionMode.nsaReady:
                return isLteNr ? "eLTE" : "e4G";
            case Fs050wConnectionMode.nr5g:
                final label = isLteNr ? "NR" : "5G";
                return isSa ? "$label SA" : label;
            case Fs050wConnectionMode.nr5gSub6:
                final label = isLteNr ? "NR+" : "5G+";
                return isSa ? "$label SA" : label;
            case Fs050wConnectionMode.disconnected:
                return "未接続";
        }
    }

    static String get4gCardTitle(Fs050wConnectionMode mode, {String notation = "4g_5g"}) {
        final isLteNr = notation == "lte_nr";
        switch (mode) {
            case Fs050wConnectionMode.lte:
                return isLteNr ? "LTE" : "4G";
            case Fs050wConnectionMode.nsaReady:
            case Fs050wConnectionMode.nr5g:
            case Fs050wConnectionMode.nr5gSub6:
                return isLteNr ? "LTE Anchor Cell" : "4G Anchor Cell";
            case Fs050wConnectionMode.disconnected:
                return isLteNr ? "LTE (未接続)" : "4G (未接続)";
        }
    }

    static String get5gCardTitle(Fs050wConnectionMode mode, {String notation = "4g_5g"}) {
        final isLteNr = notation == "lte_nr";
        switch (mode) {
            case Fs050wConnectionMode.nr5gSub6:
                return isLteNr ? "NR+ (sub6)" : "5G+ (sub6)";
            case Fs050wConnectionMode.nr5g:
                return isLteNr ? "NR" : "5G";
            case Fs050wConnectionMode.nsaReady:
                return isLteNr ? "NR (待機中)" : "5G (待機中)";
            default:
                return isLteNr ? "NR" : "5G";
        }
    }

    static String getGenerationName(bool is5g, {String notation = "4g_5g"}) {
        final isLteNr = notation == "lte_nr";
        if (is5g) {
            return isLteNr ? "NR" : "5G";
        } else {
            return isLteNr ? "LTE" : "4G";
        }
    }
}

