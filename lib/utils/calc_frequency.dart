class FrequencyCalculator {
    /// 4G LTE 周波数帯名称（スッキリした表記）
    static String getLteBandName(int? band, {String? operatorName}) {
        if (band == null || band <= 0) return "--";

        switch (band) {
            case 1:
                return "B1 (2.1GHz)";
            case 3:
                return "B3 (1.7GHz)";
            case 8:
                return "B8 (900MHz)";
            case 11:
                return "B11 (1.5GHz)";
            case 18:
                return "B18 (800MHz)";
            case 19:
                return "B19 (800MHz)";
            case 21:
                return "B21 (1.5GHz)";
            case 26:
                return "B26 (800MHz)";
            case 28:
                return "B28 (700MHz)";
            case 41:
                return "B41 (2.5GHz)";
            case 42:
                return "B42 (3.5GHz)";
            default:
                return "B$band";
        }
    }

    /// 4G LTE バッジ名称（楽天専用判定 / プラチナ / FDD / TDD）
    static String? getLteBadgeText(int? band, {String? operatorName}) {
        if (band == null || band <= 0) return null;

        final op = (operatorName ?? "").toLowerCase();
        final isRakuten = op.contains("rakuten") || op.contains("楽天");

        if (isRakuten) {
            switch (band) {
                case 3:
                    return "楽天回線";
                case 18:
                case 26:
                    return "auローミング";
                case 28:
                    return "楽天プラチナ";
            }
        }

        switch (band) {
            case 8:
            case 18:
            case 19:
            case 26:
            case 28:
                return "プラチナ";
            case 41:
            case 42:
                return "TDD";
            case 1:
            case 3:
            case 11:
            case 21:
                return "FDD";
            default:
                return null;
        }
    }

    /// 5G NR 周波数帯名称（スッキリした表記）
    static String getNrBandName(int? band, {String? operatorName}) {
        if (band == null || band <= 0) return "--";

        switch (band) {
            case 77:
                return "n77 (3.8GHz)";
            case 78:
                return "n78 (3.7GHz)";
            case 79:
                return "n79 (4.5GHz)";
            case 28:
                return "n28 (700MHz)";
            case 3:
                return "n3 (1.7GHz)";
            case 1:
                return "n1 (2.1GHz)";
            default:
                return "n$band";
        }
    }

    /// 5G NR バッジ名称（Sub6 / 転用5G のみ）
    static String? getNrBadgeText(int? band, {String? operatorName}) {
        if (band == null || band <= 0) return null;

        if (isSub6Band(band)) {
            return "Sub6";
        }

        if (isRefarmed5gBand(band)) {
            return "転用5G";
        }

        return null;
    }

    /// Sub6 帯域判定
    static bool isSub6Band(int? band) {
        if (band == null) return false;
        return band == 77 || band == 78 || band == 79;
    }

    /// 転用 5G 判定
    static bool isRefarmed5gBand(int? band) {
        if (band == null) return false;
        return band == 1 || band == 3 || band == 28;
    }
}

