enum Fs050wConnectionMode {
    lte,           // ① 4G LTE (CA無) -> [4G]
    lteCa,         // ② 4G+ LTE (CA有) -> [4G+]
    nsaReady,      // ③ 4G Ready (5G NSA待機 / CA無) -> [4GN]
    nsaReadyCa,    // ④ 4G+ Ready (5G NSA待機 / CA有) -> [4GN+]
    nr5g,          // ⑤ 5G NR (転用/通常5G/SA) -> [5G]
    nr5gSub6,      // ⑥ 5G+ NR+ (sub6高速5G/SA) -> [5G+]
    disconnected,  // 未接続
}

class ConnectionModeHelper {
    static String getIconBadgeText(Fs050wConnectionMode mode, {String notation = "4g_5g"}) {
        final isLteNr = notation == "lte_nr";
        switch (mode) {
            case Fs050wConnectionMode.lte:
                return isLteNr ? "LTE" : "4G";
            case Fs050wConnectionMode.lteCa:
                return isLteNr ? "LTE+" : "4G+";
            case Fs050wConnectionMode.nsaReady:
                return isLteNr ? "eLTE" : "e4G";
            case Fs050wConnectionMode.nsaReadyCa:
                return isLteNr ? "eLTE+" : "e4G+";
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
            case Fs050wConnectionMode.lteCa:
                return isLteNr ? "LTE+" : "4G+";
            case Fs050wConnectionMode.nsaReady:
                return isLteNr ? "eLTE" : "e4G";
            case Fs050wConnectionMode.nsaReadyCa:
                return isLteNr ? "eLTE+" : "e4G+";
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
            case Fs050wConnectionMode.lteCa:
                return isLteNr ? "LTE+" : "4G+";
            case Fs050wConnectionMode.nsaReady:
            case Fs050wConnectionMode.nsaReadyCa:
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
            case Fs050wConnectionMode.nsaReadyCa:
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

