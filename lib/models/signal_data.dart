import '../utils/calc_frequency.dart';
import 'connection_state.dart';

class SignalData {
    final DateTime timestamp;
    final String sysmode;
    final String operatorName;

    // 4G LTE Parameters
    final double? lteRsrp;
    final double? lteRssi;
    final double? lteRsrq;
    final double? lteSinr;
    final int? lteBand;
    final int? ltePci;

    // 5G NR Parameters
    final double? nrRsrp;
    final double? nrRsrq;
    final double? nrSnr;
    final int? nrBand;
    final int? nrPci;

    // Battery & CA
    final int? batteryPercent;
    final bool isCharging;
    final bool hasCa;
    final List<String> caBands;

    // Computed Connection Mode
    final Fs050wConnectionMode connectionMode;
    final bool isSa;

    // Handover info if detected in this sample
    final String? handoverDescription;

    SignalData({
        required this.timestamp,
        required this.sysmode,
        required this.operatorName,
        this.lteRsrp,
        this.lteRssi,
        this.lteRsrq,
        this.lteSinr,
        this.lteBand,
        this.ltePci,
        this.nrRsrp,
        this.nrRsrq,
        this.nrSnr,
        this.nrBand,
        this.nrPci,
        this.batteryPercent,
        this.isCharging = false,
        this.hasCa = false,
        this.caBands = const [],
        required this.connectionMode,
        this.isSa = false,
        this.handoverDescription,
    });

    factory SignalData.fromApiResponse(
        Map<String, dynamic> json, {
        bool hasCa = false,
        List<String> caBands = const [],
        SignalData? previousData,
        bool adjust5gSnr = true,
    }) {
        final Map<String, dynamic> rawMap = (json['data'] is Map<String, dynamic>)
            ? (json['data'] as Map<String, dynamic>)
            : json;
        final now = DateTime.now();
        final sysmode = (rawMap['mnet_sysmode'] ?? previousData?.sysmode ?? 'lte').toString().toLowerCase();
        final isSa = sysmode == 'nr5g';
        final operatorName = (rawMap['mnet_operator_name'] ?? previousData?.operatorName ?? '--').toString();

        // 4G LTE & 5G NR Parsing
        final rawLteRsrp = _parseInt(rawMap['mnet_rsrp']);
        final rawLteRssi = _parseInt(rawMap['mnet_rssi']);
        final rawLteRsrq = _parseInt(rawMap['mnet_rsrq']);
        final double? lteSinrVal = _parseDouble(rawMap['mnet_sinr']);
        final int? lteBandVal = _parseBand(rawMap['mnet_wnw_band']);
        final int? ltePciVal = _parseInt(rawMap['mnet_wnw_pci']);

        final rawEndcRsrp = _parseInt(rawMap['mnet_endc_rsrp']);
        final rawEndcRsrq = _parseInt(rawMap['mnet_endc_rsrq']);
        final rawEndcSnr = _parseInt(rawMap['mnet_endc_snr']);
        final int? endcBandVal = _parseBand(rawMap['mnet_wnw_psband']);
        final int? endcPciVal = _parseInt(rawMap['mnet_wnw_pspci']);

        double? lteRsrp;
        double? lteRssi;
        double? lteRsrq;
        double? lteSinr;
        int? lteBand;
        int? ltePci;

        double? nrRsrp;
        double? nrRsrq;
        double? nrSnr;
        int? nrBand;
        int? nrPci;

        if (isSa) {
            // 5G SA: Primary cell metrics are 5G
            nrRsrp = rawLteRsrp != null
                ? (rawLteRsrp - 157.0)
                : (rawEndcRsrp != null && rawEndcRsrp > 0 ? rawEndcRsrp - 157.0 : previousData?.nrRsrp);
            nrRsrq = rawLteRsrq != null
                ? (((rawLteRsrq - 1.0) / 2.0) - 43.0)
                : (rawEndcRsrq != null && rawEndcRsrq > 0 ? (((rawEndcRsrq - 1.0) / 2.0) - 43.0) : previousData?.nrRsrq);
            nrSnr = lteSinrVal ??
                (rawEndcSnr != null && rawEndcSnr > 0
                    ? (adjust5gSnr ? (((rawEndcSnr - 1.0) / 2.0) - 23.0) : rawEndcSnr.toDouble())
                    : previousData?.nrSnr);
            nrBand = lteBandVal ?? endcBandVal ?? previousData?.nrBand;
            nrPci = ltePciVal ?? endcPciVal ?? previousData?.nrPci;
        } else {
            // 4G LTE Anchor / Primary
            lteRsrp = rawLteRsrp != null ? (rawLteRsrp - 141.0) : previousData?.lteRsrp;
            lteRssi = rawLteRssi != null ? (rawLteRssi - 111.0) : previousData?.lteRssi;
            lteRsrq = rawLteRsrq != null ? ((rawLteRsrq - 40.0) / 2.0) : previousData?.lteRsrq;
            lteSinr = lteSinrVal ?? previousData?.lteSinr;
            lteBand = lteBandVal ?? previousData?.lteBand;
            ltePci = ltePciVal ?? previousData?.ltePci;

            // 5G NR ENDC Secondary
            if (rawEndcRsrp != null && rawEndcRsrp > 0) {
                nrRsrp = rawEndcRsrp - 157.0;
            } else if (rawEndcRsrp == null) {
                nrRsrp = previousData?.nrRsrp;
            }

            if (rawEndcRsrq != null && rawEndcRsrq > 0) {
                nrRsrq = ((rawEndcRsrq - 1.0) / 2.0) - 43.0;
            } else if (rawEndcRsrq == null) {
                nrRsrq = previousData?.nrRsrq;
            }

            if (rawEndcSnr != null && rawEndcSnr > 0) {
                nrSnr = adjust5gSnr
                    ? (((rawEndcSnr - 1.0) / 2.0) - 23.0)
                    : rawEndcSnr.toDouble();
            } else if (rawEndcSnr == null) {
                nrSnr = previousData?.nrSnr;
            }

            nrBand = endcBandVal ?? previousData?.nrBand;
            nrPci = endcPciVal ?? previousData?.nrPci;
        }

        // Battery
        final int? batteryPercent = _parseInt(rawMap['battery_percent']) ?? previousData?.batteryPercent;
        final bool isCharging = (rawMap['battery_charging']?.toString() == '1') || (previousData?.isCharging ?? false);

        // Mode determination
        final bool isNrActive = (nrRsrp != null && nrRsrp < 0) || (nrBand != null && nrBand > 0);
        final bool isSub6 = FrequencyCalculator.isSub6Band(nrBand);

        Fs050wConnectionMode mode;
        if (isSa) {
            mode = isSub6 ? Fs050wConnectionMode.nr5gSub6 : Fs050wConnectionMode.nr5g;
        } else if (sysmode == 'lte') {
            mode = hasCa ? Fs050wConnectionMode.lteCa : Fs050wConnectionMode.lte;
        } else if (sysmode == 'nsa') {
            if (isNrActive) {
                mode = isSub6 ? Fs050wConnectionMode.nr5gSub6 : Fs050wConnectionMode.nr5g;
            } else {
                mode = hasCa ? Fs050wConnectionMode.nsaReadyCa : Fs050wConnectionMode.nsaReady;
            }
        } else {
            mode = Fs050wConnectionMode.lte;
        }

        // Check Handover (PCI change)
        String? handover;
        if (isSa) {
            if (previousData != null && nrPci != null && previousData.nrPci != null && nrPci != previousData.nrPci) {
                final bandStr = nrBand != null ? "n$nrBand" : "";
                handover = "5G PCI ${previousData.nrPci} → $nrPci ($bandStr)";
            }
        } else {
            if (previousData != null && ltePci != null && previousData.ltePci != null && ltePci != previousData.ltePci) {
                final bandStr = lteBand != null ? "B$lteBand" : "";
                handover = "4G PCI ${previousData.ltePci} → $ltePci ($bandStr)";
            } else if (previousData != null && nrPci != null && previousData.nrPci != null && nrPci != previousData.nrPci) {
                final bandStr = nrBand != null ? "n$nrBand" : "";
                handover = "5G PCI ${previousData.nrPci} → $nrPci ($bandStr)";
            }
        }

        return SignalData(
            timestamp: now,
            sysmode: sysmode,
            operatorName: operatorName,
            lteRsrp: lteRsrp,
            lteRssi: lteRssi,
            lteRsrq: lteRsrq,
            lteSinr: lteSinr,
            lteBand: lteBand,
            ltePci: ltePci,
            nrRsrp: nrRsrp,
            nrRsrq: nrRsrq,
            nrSnr: nrSnr,
            nrBand: nrBand,
            nrPci: nrPci,
            batteryPercent: batteryPercent,
            isCharging: isCharging,
            hasCa: hasCa,
            caBands: caBands,
            connectionMode: mode,
            isSa: isSa,
            handoverDescription: handover,
        );
    }

    static int? _parseInt(dynamic val) {
        if (val == null) return null;
        if (val is int) return val;
        final s = val.toString().trim();
        if (s.isEmpty || s == '--') return null;
        return int.tryParse(s);
    }

    static double? _parseDouble(dynamic val) {
        if (val == null) return null;
        if (val is double) return val;
        if (val is int) return val.toDouble();
        final s = val.toString().trim();
        if (s.isEmpty || s == '--') return null;
        return double.tryParse(s);
    }

    static int? _parseBand(dynamic val) {
        if (val == null) return null;
        final s = val.toString().trim();
        if (s.isEmpty || s == '--') return null;
        final clean = s.replaceAll(RegExp(r'[^\d]'), '');
        return int.tryParse(clean);
    }
}
