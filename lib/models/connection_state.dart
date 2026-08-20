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

    static String get4gCardTitle(Fs050wConnectionMode mode) {
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
            case Fs050wConnectionMode.nr5gSub6:
                return "4G Anchor Cell";
            case Fs050wConnectionMode.disconnected:
                return "4G LTE (未接続)";
        }
    }

    static String get5gCardTitle(Fs050wConnectionMode mode) {
        switch (mode) {
            case Fs050wConnectionMode.nr5gSub6:
                return "5G+ NR+ (sub6)";
            case Fs050wConnectionMode.nr5g:
                return "5G NR";
            case Fs050wConnectionMode.nsaReady:
            case Fs050wConnectionMode.nsaReadyCa:
                return "5G NR (待機中)";
            default:
                return "5G NR";
        }
    }
}

