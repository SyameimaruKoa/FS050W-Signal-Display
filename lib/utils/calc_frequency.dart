class FrequencyCalculator {
    /// 4G LTE バンド名称（FDD/TDD、プラチナバンド、Rakuten専用表記対応）
    static String getLteBandName(int? band, {String? operatorName}) {
        if (band == null || band <= 0) return "--";

        final op = (operatorName ?? "").toLowerCase();
        final isRakuten = op.contains("rakuten") || op.contains("楽天");

        if (isRakuten) {
            switch (band) {
                case 3:
                    return "B3 楽天回線 (1.7GHz帯 FDD)";
                case 18:
                case 26:
                    return "B$band auローミング (800MHz帯 プラチナ)";
                case 28:
                    return "B28 楽天プラチナ (700MHz帯 プラチナ)";
            }
        }

        switch (band) {
            case 1:
                return "B1 (2.1GHz帯 FDD 主力)";
            case 3:
                return "B3 (1.7GHz帯 FDD 主力/東名阪)";
            case 8:
                return "B8 (900MHz帯 FDD プラチナ)";
            case 11:
                return "B11 (1.5GHz帯 FDD)";
            case 18:
                return "B18 (800MHz帯 FDD プラチナ)";
            case 19:
                return "B19 (800MHz帯 FDD プラチナ)";
            case 21:
                return "B21 (1.5GHz帯 FDD)";
            case 26:
                return "B26 (800MHz帯 FDD プラチナ)";
            case 28:
                return "B28 (700MHz帯 FDD プラチナ)";
            case 41:
                return "B41 (2.5GHz帯 TDD 大容量)";
            case 42:
                return "B42 (3.5GHz帯 TDD 大容量)";
            default:
                return "B$band";
        }
    }

    /// 5G NR バンド名称（Sub6 / 転用5G）
    static String getNrBandName(int? band, {String? operatorName}) {
        if (band == null || band <= 0) return "--";

        final op = (operatorName ?? "").toLowerCase();
        final isRakuten = op.contains("rakuten") || op.contains("楽天");

        if (isRakuten && band == 77) {
            return "n77 楽天Sub6 (3.8GHz帯 sub6)";
        }

        switch (band) {
            case 77:
                return "n77 (3.7GHz帯 sub6)";
            case 78:
                return "n78 (3.7GHz帯 sub6)";
            case 79:
                return "n79 (4.5GHz帯 sub6)";
            case 28:
                return "n28 (700MHz帯 転用5G)";
            case 3:
                return "n3 (1.7GHz帯 転用5G)";
            case 1:
                return "n1 (2.1GHz帯 転用5G)";
            default:
                return "n$band";
        }
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

