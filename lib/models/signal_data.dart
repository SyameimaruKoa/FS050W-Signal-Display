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

    // Battery Parameters (Official FS050W API)
    final int? batteryPercent;
    final bool isCharging;
    final int? batteryLevel;
    final int? batteryCapacity;
    final int? batteryCurrent;
    final bool isBatteryPresent;
    final double? batteryTemperature;
    final double? batteryVoltage;
    final String? batteryChargeStatus;
    final bool isLongLifeCharging;

    // Device Hardware Parameters (/action/get_device_state)
    final int? uptimeSeconds;
    final int? totalRamBytes;
    final int? usageRamBytes;
    final int? freeRamBytes;
    final int? cpuUsagePercent;
    final int? processCount;

    // Computed Connection Mode
    final Fs050wConnectionMode connectionMode;
    final bool isSa;

    // Handover info if detected in this sample
    final String? handoverDescription;

    // Router Response Speed & Mode / Wi-Fi Parameters
    final int? routerLatencyMs;
    final String? preferNetMode;
    final String? wifiState;
    final String? wifiFreq;
    final String? wifiSubFreq;
    final int? wifiClientCount;
    final String? wifiWorkStatus;

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
        this.batteryLevel,
        this.batteryCapacity,
        this.batteryCurrent,
        this.isBatteryPresent = true,
        this.batteryTemperature,
        this.batteryVoltage,
        this.batteryChargeStatus,
        this.isLongLifeCharging = false,
        this.uptimeSeconds,
        this.totalRamBytes,
        this.usageRamBytes,
        this.freeRamBytes,
        this.cpuUsagePercent,
        this.processCount,
        required this.connectionMode,
        this.isSa = false,
        this.handoverDescription,
        this.routerLatencyMs,
        this.preferNetMode,
        this.wifiState,
        this.wifiFreq,
        this.wifiSubFreq,
        this.wifiClientCount,
        this.wifiWorkStatus,
    });

    // --- Helper Getters for UI Calculation ---

    bool get is5gDisabledByConfig =>
        preferNetMode != null &&
        preferNetMode!.isNotEmpty &&
        !preferNetMode!.toLowerCase().contains('5g');

    bool get isWifiEnabled =>
        wifiState == 'ap_enable' ||
        (wifiWorkStatus != null && wifiWorkStatus == 'open' && wifiState != 'ap_disable');

    String get wifiFreqDisplay {
        if (wifiFreq == '5g') {
            final sub = wifiSubFreq != null && wifiSubFreq!.isNotEmpty ? ' (${wifiSubFreq!.toUpperCase()})' : '';
            return '5GHz$sub';
        } else if (wifiFreq == '2.4g') {
            return '2.4GHz';
        }
        return wifiFreq ?? '--';
    }

    int? get scaledBatteryPercent {
        if (batteryPercent == null) return null;
        if (isLongLifeCharging) {
            return ((batteryPercent! / 70.0) * 100).round();
        }
        return batteryPercent;
    }

    String get batteryPercentDisplay {
        if (!isBatteryPresent) return "--";
        if (batteryPercent == null) return "--";
        if (isLongLifeCharging) {
            return "$scaledBatteryPercent% (実$batteryPercent%)";
        }
        return "$batteryPercent%";
    }

    String get estimatedTimeDisplay {
        if (!isBatteryPresent || batteryPercent == null) return "--";

        final totalCap = batteryCapacity;
        final current = batteryCurrent;

        if (totalCap != null && current != null && current.abs() > 30) {
            final targetPercent = isLongLifeCharging ? 70 : 100;
            if (isCharging) {
                if (batteryPercent! >= targetPercent) {
                    return "充電完了";
                }
                final remainingMah = (totalCap * ((targetPercent - batteryPercent!) / 100.0)).round();
                if (current > 0) {
                    // Charging speed capped at 1A (1000mA) max hardware charging limit
                    final effectiveCurrent = current.clamp(1, 1000);
                    final totalMinutes = ((remainingMah / effectiveCurrent) * 60).round();
                    if (totalMinutes <= 0) return "充電完了";
                    final hours = totalMinutes ~/ 60;
                    final mins = totalMinutes % 60;
                    if (hours > 0) {
                        return "約 ${hours}時間${mins}分";
                    }
                    return "約 ${mins}分";
                }
            } else {
                final remainingMah = (totalCap * (batteryPercent! / 100.0)).round();
                final dischargeMa = current.abs();
                final totalMinutes = ((remainingMah / dischargeMa) * 60).round();
                if (totalMinutes <= 0) return "--";
                final hours = totalMinutes ~/ 60;
                final mins = totalMinutes % 60;
                if (hours > 0) {
                    return "約 ${hours}時間${mins}分";
                }
                return "約 ${mins}分";
            }
        }

        if (isCharging) {
            final targetPercent = isLongLifeCharging ? 70 : 100;
            if (batteryPercent! >= targetPercent) {
                return "充電完了";
            }
            return "充電中...";
        } else {
            return "バッテリー駆動中";
        }
    }

    String? get remainingTimeHHMM {
        if (!isBatteryPresent || batteryPercent == null) return null;
        final totalCap = batteryCapacity;
        final current = batteryCurrent;
        if (totalCap == null || current == null || current.abs() <= 30) return null;

        final targetPercent = isLongLifeCharging ? 70 : 100;
        if (isCharging) {
            if (batteryPercent! >= targetPercent) return null;
            final remainingMah = (totalCap * ((targetPercent - batteryPercent!) / 100.0)).round();
            if (current > 0) {
                final effectiveCurrent = current.clamp(1, 1000);
                final totalMinutes = ((remainingMah / effectiveCurrent) * 60).round();
                if (totalMinutes <= 0) return null;
                final hours = totalMinutes ~/ 60;
                final mins = totalMinutes % 60;
                final minsStr = mins.toString().padLeft(2, '0');
                return "$hours:$minsStr";
            }
        } else {
            final remainingMah = (totalCap * (batteryPercent! / 100.0)).round();
            final dischargeMa = current.abs();
            final totalMinutes = ((remainingMah / dischargeMa) * 60).round();
            if (totalMinutes <= 0) return null;
            final hours = totalMinutes ~/ 60;
            final mins = totalMinutes % 60;
            final minsStr = mins.toString().padLeft(2, '0');
            return "$hours:$minsStr";
        }
        return null;
    }

    String get formattedUptime {
        if (uptimeSeconds == null) return "--";
        final sec = uptimeSeconds!;
        final days = sec ~/ 86400;
        final hours = (sec % 86400) ~/ 3600;
        final mins = (sec % 3600) ~/ 60;
        final secs = sec % 60;

        if (days > 0) {
            return "$days日 $hours時間 $mins分";
        } else if (hours > 0) {
            return "$hours時間 $mins分 $secs秒";
        } else {
            return "$mins分 $secs秒";
        }
    }

    String get formattedRamUsage {
        if (usageRamBytes == null || totalRamBytes == null || totalRamBytes == 0) return "--";
        final usedMb = (usageRamBytes! / (1024 * 1024)).toStringAsFixed(0);
        final totalMb = (totalRamBytes! / (1024 * 1024)).toStringAsFixed(0);
        final percent = ((usageRamBytes! / totalRamBytes!) * 100).toStringAsFixed(1);
        return "$usedMb MB / $totalMb MB ($percent%)";
    }

    static String normalizeOperatorName(String raw) {
        final trimmed = raw.trim();
        final clean = trimmed.replaceAll(' ', '');
        if (clean == '44011' || clean == '44053') return 'Rakuten';
        if (clean == '44010' || clean == '44001') return 'NTT DOCOMO';
        if (clean == '44050' || clean == '44051' || clean == '44052' || clean == '44054') return 'au';
        if (clean == '44020' || clean == '44000') return 'SoftBank';
        return trimmed.isEmpty ? '--' : trimmed;
    }

    factory SignalData.fromApiResponse(
        Map<String, dynamic> json, {
        Map<String, dynamic>? deviceStateJson,
        SignalData? previousData,
        bool adjust5gSnr = true,
        int? routerLatencyMs,
    }) {
        final Map<String, dynamic> rawMap = (json['data'] is Map<String, dynamic>)
            ? (json['data'] as Map<String, dynamic>)
            : json;
        final now = DateTime.now();
        final sysmode = (rawMap['mnet_sysmode'] ?? previousData?.sysmode ?? 'lte').toString().toLowerCase();
        final isSa = sysmode == 'nr5g';
        final rawOp = (rawMap['mnet_operator_name'] ?? previousData?.operatorName ?? '--').toString();
        final operatorName = normalizeOperatorName(rawOp);

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
            final resolvedNrPci = ltePciVal ?? endcPciVal;
            nrPci = (resolvedNrPci != null && resolvedNrPci > 0) ? resolvedNrPci : (resolvedNrPci == 0 ? null : previousData?.nrPci);
        } else if (sysmode == 'lte') {
            // 4G LTE Pure Mode (5G is disabled / out of service)
            lteRsrp = rawLteRsrp != null ? (rawLteRsrp - 141.0) : previousData?.lteRsrp;
            lteRssi = rawLteRssi != null ? (rawLteRssi - 111.0) : previousData?.lteRssi;
            lteRsrq = rawLteRsrq != null ? ((rawLteRsrq - 40.0) / 2.0) : previousData?.lteRsrq;
            lteSinr = lteSinrVal ?? previousData?.lteSinr;
            lteBand = lteBandVal ?? previousData?.lteBand;
            ltePci = (ltePciVal != null && ltePciVal > 0) ? ltePciVal : (ltePciVal == 0 ? null : previousData?.ltePci);

            nrRsrp = null;
            nrRsrq = null;
            nrSnr = null;
            nrBand = null;
            nrPci = null;
        } else {
            // 4G LTE Anchor / Primary
            lteRsrp = rawLteRsrp != null ? (rawLteRsrp - 141.0) : previousData?.lteRsrp;
            lteRssi = rawLteRssi != null ? (rawLteRssi - 111.0) : previousData?.lteRssi;
            lteRsrq = rawLteRsrq != null ? ((rawLteRsrq - 40.0) / 2.0) : previousData?.lteRsrq;
            lteSinr = lteSinrVal ?? previousData?.lteSinr;
            lteBand = lteBandVal ?? previousData?.lteBand;
            ltePci = (ltePciVal != null && ltePciVal > 0) ? ltePciVal : (ltePciVal == 0 ? null : previousData?.ltePci);

            // 5G NR ENDC Secondary
            if (rawEndcRsrp != null && rawEndcRsrp > 0) {
                nrRsrp = rawEndcRsrp - 157.0;
            } else if (rawEndcRsrp == 0 || (rawMap.containsKey('mnet_endc_rsrp') && rawEndcRsrp == null)) {
                nrRsrp = null;
            } else {
                nrRsrp = previousData?.nrRsrp;
            }

            if (rawEndcRsrq != null && rawEndcRsrq > 0) {
                nrRsrq = ((rawEndcRsrq - 1.0) / 2.0) - 43.0;
            } else if (rawEndcRsrq == 0 || (rawMap.containsKey('mnet_endc_rsrq') && rawEndcRsrq == null)) {
                nrRsrq = null;
            } else {
                nrRsrq = previousData?.nrRsrq;
            }

            if (rawEndcSnr != null && rawEndcSnr > 0) {
                nrSnr = adjust5gSnr
                    ? (((rawEndcSnr - 1.0) / 2.0) - 23.0)
                    : rawEndcSnr.toDouble();
            } else if (rawEndcSnr == 0 || (rawMap.containsKey('mnet_endc_snr') && rawEndcSnr == null)) {
                nrSnr = null;
            } else {
                nrSnr = previousData?.nrSnr;
            }

            // When ENDC RSRP is explicitly 0 or pspci is 0 (5G out of service/waiting), clear all 5G secondary cell info
            final bool is5gInactive = (rawMap.containsKey('mnet_endc_rsrp') && rawEndcRsrp == 0) || endcPciVal == 0;
            if (is5gInactive) {
                nrBand = null;
                nrPci = null;
            } else {
                nrBand = (endcBandVal != null && endcBandVal > 0) ? endcBandVal : (endcBandVal == 0 ? null : previousData?.nrBand);
                nrPci = (endcPciVal != null && endcPciVal > 0) ? endcPciVal : (endcPciVal == 0 ? null : previousData?.nrPci);
            }
        }

        // Official FS050W Battery Parameters Parsing
        final String? rawExist = rawMap['device_battery_exist']?.toString().toLowerCase();
        final bool isBatteryPresent = rawExist == null
            ? (previousData?.isBatteryPresent ?? true)
            : (rawExist == 'present' || rawExist == '1');

        final int? rawLevelPercent = _parseInt(rawMap['device_battery_level_percent']) ?? _parseInt(rawMap['battery_percent']);
        final int? rawLevel = _parseInt(rawMap['device_battery_level']);
        final int? rawCap = _parseInt(rawMap['device_battery_capacity']) ?? previousData?.batteryCapacity;
        final int? rawCurr = _parseInt(rawMap['device_battery_current']) ?? previousData?.batteryCurrent;
        double? rawTemp = _parseDouble(rawMap['device_battery_temperature']) ?? previousData?.batteryTemperature;
        if (rawTemp != null && (rawTemp < -30 || rawTemp > 100)) {
            rawTemp = null;
        }
        final double? rawVolt = _parseDouble(rawMap['device_battery_voltage']) ?? previousData?.batteryVoltage;
        final String? rawChargeStatus = rawMap['device_battery_charge_status']?.toString().toLowerCase() ?? previousData?.batteryChargeStatus;
        final String? rawLongLife = rawMap['device_charge_long_life']?.toString().toLowerCase() ?? (previousData?.isLongLifeCharging == true ? 'enable' : 'disable');
        final bool isLongLife = rawLongLife == 'enable' || rawLongLife == '1';

        // Calculate batteryPercent (Sanitize to null if battery is absent)
        int? batteryPercent;
        bool isCharging = false;
        int? resolvedLevel = rawLevel;
        int? resolvedCap = rawCap;
        int? resolvedCurr = rawCurr;
        double? resolvedTemp = rawTemp;
        double? resolvedVolt = rawVolt;
        String? resolvedChargeStatus = rawChargeStatus;

        if (isBatteryPresent) {
            batteryPercent = rawLevelPercent;
            if (batteryPercent == null && rawLevel != null && rawLevel > 4) {
                batteryPercent = rawLevel.clamp(0, 100);
            }
            batteryPercent ??= previousData?.batteryPercent;

            isCharging = rawChargeStatus == 'charging' ||
                (rawMap['battery_charging']?.toString() == '1') ||
                (rawCurr != null && rawCurr > 0) ||
                (previousData?.isCharging ?? false);
        } else {
            // When battery is absent, sanitize all battery metrics
            batteryPercent = null;
            resolvedLevel = null;
            resolvedCap = null;
            resolvedCurr = null;
            resolvedTemp = null;
            resolvedVolt = null;
            resolvedChargeStatus = null;
            isCharging = false;
        }

        // Hardware state parameters (/action/get_device_state)
        final Map<String, dynamic>? devState = deviceStateJson ?? (rawMap['uptime'] != null ? rawMap : null);
        final int? uptimeSec = _parseInt(devState?['uptime']) ?? previousData?.uptimeSeconds;
        final int? totalRam = _parseInt(devState?['totalram']) ?? previousData?.totalRamBytes;
        final int? usageRam = _parseInt(devState?['usageram']) ?? previousData?.usageRamBytes;
        final int? freeRam = _parseInt(devState?['freeram']) ?? previousData?.freeRamBytes;
        final int? cpuUsage = _parseInt(devState?['cpuusage']) ?? previousData?.cpuUsagePercent;
        final int? procs = _parseInt(devState?['procs']) ?? previousData?.processCount;

        // Mode determination (CA is not supported by hardware API)
        final bool isNrActive = (nrRsrp != null && nrRsrp < 0) || (nrBand != null && nrBand > 0);
        final bool isSub6 = FrequencyCalculator.isSub6Band(nrBand);

        Fs050wConnectionMode mode;
        if (isSa) {
            mode = isSub6 ? Fs050wConnectionMode.nr5gSub6 : Fs050wConnectionMode.nr5g;
        } else if (sysmode == 'lte') {
            mode = Fs050wConnectionMode.lte;
        } else if (sysmode == 'nsa') {
            if (isNrActive) {
                mode = isSub6 ? Fs050wConnectionMode.nr5gSub6 : Fs050wConnectionMode.nr5g;
            } else {
                mode = Fs050wConnectionMode.nsaReady;
            }
        } else {
            mode = Fs050wConnectionMode.lte;
        }

        // Check Handover (PCI change: both previous and current must be valid > 0)
        String? handover;
        if (isSa) {
            if (previousData != null &&
                nrPci != null && nrPci > 0 &&
                previousData.nrPci != null && previousData.nrPci! > 0 &&
                nrPci != previousData.nrPci) {
                final bandStr = (nrBand != null && nrBand > 0) ? "n$nrBand" : "";
                handover = "5G PCI ${previousData.nrPci} → $nrPci ($bandStr)";
            }
        } else {
            if (previousData != null &&
                ltePci != null && ltePci > 0 &&
                previousData.ltePci != null && previousData.ltePci! > 0 &&
                ltePci != previousData.ltePci) {
                final bandStr = (lteBand != null && lteBand > 0) ? "B$lteBand" : "";
                handover = "4G PCI ${previousData.ltePci} → $ltePci ($bandStr)";
            } else if (previousData != null &&
                nrPci != null && nrPci > 0 &&
                previousData.nrPci != null && previousData.nrPci! > 0 &&
                nrPci != previousData.nrPci) {
                final bandStr = (nrBand != null && nrBand > 0) ? "n$nrBand" : "";
                handover = "5G PCI ${previousData.nrPci} → $nrPci ($bandStr)";
            }
        }

        // 4G/5G Router Preference & Wi-Fi Parsing
        final String? rawPreferNet = rawMap['mnet_acqorder']?.toString() ?? previousData?.preferNetMode;
        final String? rawWifiState = rawMap['wifi_state_0']?.toString() ?? previousData?.wifiState;
        final String? rawWifiFreq = rawMap['wifi_freq_0']?.toString() ?? previousData?.wifiFreq;
        final String? rawWifiSubFreq = rawMap['wifi_5g_sub_freq']?.toString() ?? previousData?.wifiSubFreq;
        final int? rawWifiClients = _parseInt(rawMap['wifi_client_0']) ?? previousData?.wifiClientCount;
        final String? rawWifiWork = rawMap['wifi_work_status']?.toString() ?? previousData?.wifiWorkStatus;

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
            batteryLevel: resolvedLevel,
            batteryCapacity: resolvedCap,
            batteryCurrent: resolvedCurr,
            isBatteryPresent: isBatteryPresent,
            batteryTemperature: resolvedTemp,
            batteryVoltage: resolvedVolt,
            batteryChargeStatus: resolvedChargeStatus,
            isLongLifeCharging: isLongLife,
            uptimeSeconds: uptimeSec,
            totalRamBytes: totalRam,
            usageRamBytes: usageRam,
            freeRamBytes: freeRam,
            cpuUsagePercent: cpuUsage,
            processCount: procs,
            connectionMode: mode,
            isSa: isSa,
            handoverDescription: handover,
            routerLatencyMs: routerLatencyMs ?? previousData?.routerLatencyMs,
            preferNetMode: rawPreferNet,
            wifiState: rawWifiState,
            wifiFreq: rawWifiFreq,
            wifiSubFreq: rawWifiSubFreq,
            wifiClientCount: rawWifiClients,
            wifiWorkStatus: rawWifiWork,
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
        final parsed = int.tryParse(clean);
        if (parsed == null || parsed <= 0) return null;
        return parsed;
    }
}
