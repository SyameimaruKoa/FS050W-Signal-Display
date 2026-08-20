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
    static String getIconBadgeText(Fs050wConnectionMode mode) {
        switch (mode) {
            case Fs050wConnectionMode.lte:
                return "4G";
            case Fs050wConnectionMode.lteCa:
                return "4G+";
            case Fs050wConnectionMode.nsaReady:
                return "4GN";
            case Fs050wConnectionMode.nsaReadyCa:
                return "4GN+";
            case Fs050wConnectionMode.nr5g:
                return "5G";
            case Fs050wConnectionMode.nr5gSub6:
                return "5G+";
            case Fs050wConnectionMode.disconnected:
                return "--";
        }
    }

    static String getUiModeText(Fs050wConnectionMode mode, {bool isSa = false}) {
        switch (mode) {
            case Fs050wConnectionMode.lte:
                return "4G LTE";
            case Fs050wConnectionMode.lteCa:
                return "4G+ LTE";
            case Fs050wConnectionMode.nsaReady:
                return "4G Ready";
            case Fs050wConnectionMode.nsaReadyCa:
                return "4G+ Ready";
            case Fs050wConnectionMode.nr5g:
                return isSa ? "5G NR SA" : "5G NR";
            case Fs050wConnectionMode.nr5gSub6:
                return isSa ? "5G+ NR+ SA" : "5G+ NR+";
            case Fs050wConnectionMode.disconnected:
                return "未接続";
        }
    }

    static String get4gAnchorText(Fs050wConnectionMode mode, String bandText, {bool hasCa = false, List<String>? caBands}) {
        switch (mode) {
            case Fs050wConnectionMode.lte:
                return "4G LTE ($bandText)";
            case Fs050wConnectionMode.lteCa:
                final caInfo = (caBands != null && caBands.isNotEmpty) ? "$bandText+${caBands.join('+')}" : "$bandText+CA";
                return "4G+ LTE ($caInfo)";
            case Fs050wConnectionMode.nsaReady:
                return "4G Ready ($bandText)";
            case Fs050wConnectionMode.nsaReadyCa:
                final caInfo = (caBands != null && caBands.isNotEmpty) ? "$bandText+${caBands.join('+')}" : "$bandText+CA";
                return "4G+ Ready ($caInfo)";
            case Fs050wConnectionMode.nr5g:
            case Fs050wConnectionMode.nr5gSub6:
                return "4G Anchor ($bandText)";
            case Fs050wConnectionMode.disconnected:
                return "未接続";
        }
    }

    static String get5gNrText(Fs050wConnectionMode mode, String nrBandText) {
        switch (mode) {
            case Fs050wConnectionMode.lte:
            case Fs050wConnectionMode.lteCa:
                return "非表示";
            case Fs050wConnectionMode.nsaReady:
            case Fs050wConnectionMode.nsaReadyCa:
                return "待機中 (--)";
            case Fs050wConnectionMode.nr5g:
                return "5G NR ($nrBandText)";
            case Fs050wConnectionMode.nr5gSub6:
                return "5G+ NR+ ($nrBandText)";
            case Fs050wConnectionMode.disconnected:
                return "--";
        }
    }
}
