class FrequencyCalculator {
    static String getLteBandName(int? band) {
        if (band == null || band <= 0) return "--";
        switch (band) {
            case 1:
                return "B1 (2.1GHz帯)";
            case 3:
                return "B3 (1.7GHz帯)";
            case 8:
                return "B8 (900MHz帯)";
            case 18:
                return "B18 (800MHz帯)";
            case 19:
                return "B19 (800MHz帯)";
            case 21:
                return "B21 (1.5GHz帯)";
            case 26:
                return "B26 (800MHz帯)";
            case 28:
                return "B28 (700MHz帯)";
            case 41:
                return "B41 (2.5GHz帯)";
            case 42:
                return "B42 (3.5GHz帯)";
            default:
                return "B$band";
        }
    }

    static String getNrBandName(int? band) {
        if (band == null || band <= 0) return "--";
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

    static bool isSub6Band(int? band) {
        if (band == null) return false;
        return band == 77 || band == 78 || band == 79;
    }
}

