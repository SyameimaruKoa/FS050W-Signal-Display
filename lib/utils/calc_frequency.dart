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

    static double? calculateLteFrequency(int? band, int? earfcn) {
        if (earfcn == null) return null;
        if (band == null) {
            if (earfcn >= 0 && earfcn <= 599) band = 1;
            else if (earfcn >= 1200 && earfcn <= 1949) band = 3;
            else if (earfcn >= 3450 && earfcn <= 3799) band = 8;
            else if (earfcn >= 5850 && earfcn <= 5999) band = 18;
            else if (earfcn >= 6000 && earfcn <= 6149) band = 19;
            else if (earfcn >= 6450 && earfcn <= 6599) band = 21;
            else if (earfcn >= 8690 && earfcn <= 9039) band = 26;
            else if (earfcn >= 9210 && earfcn <= 9659) band = 28;
            else if (earfcn >= 39650 && earfcn <= 41589) band = 41;
            else if (earfcn >= 41590 && earfcn <= 43589) band = 42;
        }

        switch (band) {
            case 1:
                return 2110.0 + 0.1 * (earfcn - 0);
            case 3:
                return 1805.0 + 0.1 * (earfcn - 1200);
            case 8:
                return 925.0 + 0.1 * (earfcn - 3450);
            case 18:
                return 860.0 + 0.1 * (earfcn - 5850);
            case 19:
                return 875.0 + 0.1 * (earfcn - 6000);
            case 21:
                return 1495.9 + 0.1 * (earfcn - 6450);
            case 26:
                return 859.0 + 0.1 * (earfcn - 8690);
            case 28:
                return 758.0 + 0.1 * (earfcn - 9210);
            case 41:
                return 2496.0 + 0.1 * (earfcn - 39650);
            case 42:
                return 3400.0 + 0.1 * (earfcn - 41590);
            default:
                return null;
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

    static double? calculateNrFrequency(int? band, int? arfcn) {
        if (arfcn == null) return null;
        if (arfcn >= 600000 && arfcn <= 2016666) {
            return 3000.0 + 0.015 * (arfcn - 600000);
        } else if (arfcn >= 0 && arfcn < 600000) {
            return 0.0 + 0.005 * (arfcn - 0);
        }
        return null;
    }
}
