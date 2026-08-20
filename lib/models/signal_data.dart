import 'package:flutter/foundation.dart';
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
    final int? lteEarfcn;
    final double? lteFrequency;

    // 5G NR Parameters
    final double? nrRsrp;
    final double? nrRsrq;
    final double? nrSnr;
    final int? nrBand;
    final int? nrPci;
    final int? nrArfcn;
    final double? nrFrequency;

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
        this.lteEarfcn,
        this.lteFrequency,
        this.nrRsrp,
        this.nrRsrq,
        this.nrSnr,
        this.nrBand,
        this.nrPci,
        this.nrArfcn,
        this.nrFrequency,
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
    }) {
        final now = DateTime.now();
        final sysmode = (json['mnet_sysmode'] ?? 'lte').toString().toLowerCase();
        final isSa = sysmode == 'nr5g';
        final operatorName = (json['mnet_operator_name'] ?? '--').toString();

        // 4G LTE Parsing
        final rawLteRsrp = _parseInt(json['mnet_rsrp']);
        double? lteRsrp;
        if (rawLteRsrp != null) {
            lteRsrp = isSa ? (rawLteRsrp - 157.0) : (rawLteRsrp - 141.0);
        }

        final rawLteRssi = _parseInt(json['mnet_rssi']);
        final double? lteRssi = rawLteRssi != null ? (rawLteRssi - 111.0) : null;

        final rawLteRsrq = _parseInt(json['mnet_rsrq']);
        final double? lteRsrq = rawLteRsrq != null ? ((rawLteRsrq - 40.0) / 2.0) : null;

        final double? lteSinr = _parseDouble(json['mnet_sinr']);

        final int? lteBand = _parseBand(json['mnet_wnw_band']);
        final int? ltePci = _parseInt(json['mnet_wnw_pci']);
        final int? lteEarfcn = _parseInt(json['mnet_wnw_earfcn']);
        final double? lteFrequency = FrequencyCalculator.calculateLteFrequency(lteBand, lteEarfcn);

        // 5G NR Parsing
        final rawEndcRsrp = _parseInt(json['mnet_endc_rsrp']);
        double? nrRsrp;
        if (rawEndcRsrp != null && rawEndcRsrp > 0) {
            nrRsrp = rawEndcRsrp - 157.0;
        }

        final rawEndcRsrq = _parseInt(json['mnet_endc_rsrq']);
        double? nrRsrq;
        if (rawEndcRsrq != null && rawEndcRsrq > 0) {
            nrRsrq = ((rawEndcRsrq - 1.0) / 2.0) - 43.0;
        }

        final rawEndcSnr = _parseInt(json['mnet_endc_snr']);
        double? nrSnr;
        if (rawEndcSnr != null && rawEndcSnr > 0) {
            nrSnr = ((rawEndcSnr - 1.0) / 2.0) - 23.0;
        }

        final int? nrBand = _parseBand(json['mnet_wnw_psband']);
        final int? nrPci = _parseInt(json['mnet_wnw_pspci']);
        final int? nrArfcn = _parseInt(json['mnet_wnw_psnrarfcn']);
        final double? nrFrequency = FrequencyCalculator.calculateNrFrequency(nrBand, nrArfcn);

        // Battery
        final int? batteryPercent = _parseInt(json['battery_percent']);
        final bool isCharging = (json['battery_charging']?.toString() == '1');

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
        if (previousData != null && ltePci != null && previousData.ltePci != null && ltePci != previousData.ltePci) {
            final bandStr = lteBand != null ? "B$lteBand" : "";
            handover = "PCI ${previousData.ltePci} → $ltePci ($bandStr)";
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
            lteEarfcn: lteEarfcn,
            lteFrequency: lteFrequency,
            nrRsrp: nrRsrp,
            nrRsrq: nrRsrq,
            nrSnr: nrSnr,
            nrBand: nrBand,
            nrPci: nrPci,
            nrArfcn: nrArfcn,
            nrFrequency: nrFrequency,
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
