import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/pip_service.dart';
import '../../models/signal_data.dart';
import '../../models/connection_state.dart';
import '../hud_screen.dart';
import '../settings_screen.dart';
import 'log_viewer_dialog.dart';

class Fs050wAppBar extends StatelessWidget implements PreferredSizeWidget {
    final List<Widget>? actions;
    final bool showDefaultActions;
    final Widget? leading;

    const Fs050wAppBar({
        super.key,
        this.actions,
        this.showDefaultActions = true,
        this.leading,
    });

    @override
    Size get preferredSize => const Size.fromHeight(kToolbarHeight);

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AppBar(
            leading: leading,
            titleSpacing: leading != null ? 0 : NavigationToolbar.kMiddleSpacing,
            title: InkWell(
                onTap: () => BatterySystemDetailSheet.show(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
                    child: _buildHeaderContent(context, signal, apiService),
                ),
            ),
            actions: actions ?? (showDefaultActions ? _buildDefaultActions(context, apiService, isDark) : null),
        );
    }

    Widget _buildHeaderContent(BuildContext context, SignalData? signal, ApiService apiService) {
        final mode = signal?.connectionMode ?? Fs050wConnectionMode.disconnected;
        final notation = apiService.settings.generationNotation;
        final modeBadge = ConnectionModeHelper.getIconBadgeText(mode, notation: notation);
        final isConnecting = apiService.isConnecting;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final isTempWarning = apiService.settings.batteryTempWarningEnabled &&
            signal?.batteryTemperature != null &&
            signal!.batteryTemperature! >= apiService.settings.batteryTempWarningThreshold;

        final hasBattery = signal?.isBatteryPresent ?? true;
        final batPercent = signal?.scaledBatteryPercent ?? signal?.batteryPercent;
        final isCharging = signal?.isCharging ?? false;
        final temp = signal?.batteryTemperature;
        final curr = signal?.batteryCurrent;

        final String batText;
        if (!hasBattery) {
            batText = "AC給電";
        } else if (batPercent == null) {
            batText = "--";
        } else {
            final chargeIcon = isCharging ? "⚡" : "";
            batText = "$batPercent%$chargeIcon";
        }

        final String tempText = temp != null ? "${temp.round()}℃" : "--";
        final String currText = curr != null ? "${curr > 0 ? '+$curr' : curr}mA" : "";

        final Color tempColor = isTempWarning
            ? Colors.redAccent
            : (isDark
                ? _getTempColor(temp, apiService.settings.batteryTempWarningThreshold)
                : _getLightTempColor(temp, apiService.settings.batteryTempWarningThreshold));

        final Color currColor = isCharging
            ? (isDark ? Colors.amberAccent : Colors.orange.shade800)
            : (isDark ? Colors.white60 : Colors.black54);

        final Color chargeIconColor = isDark ? Colors.amberAccent : Colors.orange.shade800;

        return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                // 1. Antenna Pict Icon & Badge
                _buildAntennaPict(signal, mode, modeBadge, isConnecting, isDark),
                const SizedBox(width: 8),

                // 2. Compact Battery & Hardware Summary
                Flexible(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Icon(
                                        !hasBattery
                                            ? Icons.power
                                            : isCharging
                                                ? Icons.battery_charging_full
                                                : _getBatteryIcon(batPercent),
                                        size: 14,
                                        color: !hasBattery
                                            ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F))
                                            : isCharging
                                                ? chargeIconColor
                                                : _getBatteryColor(batPercent),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                        batText,
                                        style: TextStyle(
                                            fontSize: !hasBattery ? 12 : 13,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: !hasBattery ? null : 'monospace',
                                        ),
                                    ),
                                    const SizedBox(width: 6),
                                    if (hasBattery && temp != null)
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                            color: isTempWarning
                                                ? Colors.red.withOpacity(0.25)
                                                : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                                color: isTempWarning
                                                    ? Colors.redAccent
                                                    : Colors.transparent,
                                                width: 0.8,
                                            ),
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                if (isTempWarning)
                                                    const Padding(
                                                        padding: EdgeInsets.only(right: 2),
                                                        child: Icon(Icons.warning_amber_rounded, size: 11, color: Colors.redAccent),
                                                    ),
                                                Text(
                                                    tempText,
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: tempColor,
                                                        fontFamily: 'monospace',
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                    if (hasBattery && currText.isNotEmpty) ...[
                                        const SizedBox(width: 5),
                                        Text(
                                            currText,
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                color: currColor,
                                                fontFamily: 'monospace',
                                            ),
                                        ),
                                    ],
                                ],
                            ),
                            const SizedBox(height: 1),
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Text(
                                        signal?.operatorName ?? "FS050W",
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                            fontWeight: FontWeight.w600,
                                        ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                        Icons.touch_app,
                                        size: 10,
                                        color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F),
                                    ),
                                    Text(
                                        "詳細",
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F),
                                            fontWeight: FontWeight.w600,
                                        ),
                                    ),
                                ],
                            ),
                        ],
                    ),
                ),
            ],
        );
    }

    Widget _buildAntennaPict(SignalData? signal, Fs050wConnectionMode mode, String modeBadge, bool isConnecting, bool isDark) {
        if (isConnecting) {
            return Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: isDark ? Colors.amberAccent : Colors.orange.shade800, width: 0.8),
                ),
                child: Text(
                    "接続中",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.amberAccent : Colors.orange.shade800,
                    ),
                ),
            );
        }

        // Calculate bar count (0..4) based on best RSRP
        final rsrp = signal?.nrRsrp ?? signal?.lteRsrp;
        final int barCount;
        if (rsrp == null || rsrp <= -120) {
            barCount = 0;
        } else if (rsrp <= -110) {
            barCount = 1;
        } else if (rsrp <= -100) {
            barCount = 2;
        } else if (rsrp <= -90) {
            barCount = 3;
        } else {
            barCount = 4;
        }

        final Color themeColor = mode == Fs050wConnectionMode.nr5gSub6 || mode == Fs050wConnectionMode.nr5g
            ? (isDark ? const Color(0xFF00ADB5) : const Color(0xFF00838F))
            : const Color(0xFF2196F3);

        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
                color: themeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: themeColor.withOpacity(0.6), width: 1),
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    // Signal Bars Icon
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(4, (index) {
                            final isActive = index < barCount;
                            final barHeight = 4.0 + (index * 2.8);
                            return Container(
                                width: 2.5,
                                height: barHeight,
                                margin: const EdgeInsets.symmetric(horizontal: 0.7),
                                decoration: BoxDecoration(
                                    color: isActive ? themeColor : (isDark ? Colors.white24 : Colors.black12),
                                    borderRadius: BorderRadius.circular(1),
                                ),
                            );
                        }),
                    ),
                    const SizedBox(width: 4),
                    Text(
                        modeBadge,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                        ),
                    ),
                ],
            ),
        );
    }

    IconData _getBatteryIcon(int? percent) {
        if (percent == null) return Icons.battery_unknown;
        if (percent >= 90) return Icons.battery_full;
        if (percent >= 70) return Icons.battery_6_bar;
        if (percent >= 50) return Icons.battery_4_bar;
        if (percent >= 30) return Icons.battery_3_bar;
        if (percent >= 15) return Icons.battery_2_bar;
        return Icons.battery_alert;
    }

    Color _getBatteryColor(int? percent) {
        if (percent == null) return Colors.grey;
        if (percent >= 50) return const Color(0xFF4CAF50);
        if (percent >= 20) return Colors.amberAccent;
        return Colors.redAccent;
    }

    Color _getTempColor(double? temp, [double threshold = 45.0]) {
        if (temp == null) return Colors.white70;
        if (temp >= threshold) return Colors.redAccent;
        if (temp >= threshold - 5.0) return Colors.amberAccent;
        return const Color(0xFF00E5FF);
    }

    Color _getLightTempColor(double? temp, [double threshold = 45.0]) {
        if (temp == null) return Colors.black54;
        if (temp >= threshold) return Colors.red.shade800;
        if (temp >= threshold - 5.0) return Colors.orange.shade900;
        return const Color(0xFF00838F);
    }

    List<Widget> _buildDefaultActions(BuildContext context, ApiService apiService, bool isDark) {
        return [
            IconButton(
                icon: const Icon(Icons.picture_in_picture_alt, color: Color(0xFF00E5FF)),
                tooltip: "PiP (小窓表示) 起動",
                onPressed: () async {
                    final success = await PipService.enterPipMode(apiService.settings.pipAspectRatio);
                    if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("PiPモードの起動に失敗しました (端末の設定をご確認ください)")),
                        );
                    }
                },
            ),
            IconButton(
                icon: Icon(Icons.assignment_outlined, color: isDark ? Colors.white70 : Colors.black87),
                tooltip: "診断ログを表示",
                onPressed: () => LogViewerDialog.show(context),
            ),
            IconButton(
                icon: const Icon(Icons.bedtime, color: Colors.amberAccent),
                tooltip: "HUD / 有機EL 常時表示モード",
                onPressed: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const HudScreen()),
                    );
                },
            ),
        ];
    }
}

// ----------------------------------------------------
// Battery & System Detail Bottom Sheet Modal
// ----------------------------------------------------
class BatterySystemDetailSheet extends StatelessWidget {
    const BatterySystemDetailSheet({super.key});

    static void show(BuildContext context) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const BatterySystemDetailSheet(),
        );
    }

    @override
    Widget build(BuildContext context) {
        final apiService = context.watch<ApiService>();
        final signal = apiService.currentSignal;
        final isLoggedIn = apiService.isLoggedIn;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

        return DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
                return Container(
                    decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                            ),
                        ],
                    ),
                    child: Column(
                        children: [
                            // Drag handle
                            Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(2),
                                ),
                            ),

                            // Header
                            Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Row(
                                            children: [
                                                const Icon(Icons.analytics_outlined, color: Color(0xFF00ADB5)),
                                                const SizedBox(width: 8),
                                                Text(
                                                    "ルーター詳細統計・バッテリー情報",
                                                    style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                ),
                                            ],
                                        ),
                                        IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed: () => Navigator.of(context).pop(),
                                        ),
                                    ],
                                ),
                            ),
                            const Divider(height: 1),

                            // Scrollable details
                            Expanded(
                                child: ListView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(16.0),
                                    children: [
                                        // 1. Estimated Usage / Charging Time
                                        _buildEstimateCard(signal, isDark),
                                        const SizedBox(height: 12),

                                        // 2. Battery Detailed Metrics
                                        _buildBatteryCard(signal, isDark),
                                        const SizedBox(height: 12),

                                        // 3. System Hardware State (/action/get_device_state)
                                        _buildHardwareCard(signal, isLoggedIn, isDark, context),
                                    ],
                                ),
                            ),
                        ],
                    ),
                );
            },
        );
    }

    Widget _buildEstimateCard(SignalData? signal, bool isDark) {
        final estimateStr = signal?.estimatedTimeDisplay ?? "--";
        final isCharging = signal?.isCharging ?? false;
        final hasBattery = signal?.isBatteryPresent ?? true;

        return Card(
            color: isDark ? const Color(0xFF252525) : Colors.grey.shade100,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: !hasBattery
                        ? (isDark ? const Color(0xFF00E5FF).withOpacity(0.4) : const Color(0xFF00838F).withOpacity(0.4))
                        : (isCharging ? Colors.amberAccent.withOpacity(0.5) : const Color(0xFF00ADB5).withOpacity(0.4)),
                    width: 1.2,
                ),
            ),
            child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                    children: [
                        Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: !hasBattery
                                    ? (isDark ? const Color(0xFF00E5FF).withOpacity(0.15) : const Color(0xFF00838F).withOpacity(0.15))
                                    : (isCharging
                                        ? Colors.amber.withOpacity(0.15)
                                        : const Color(0xFF00ADB5).withOpacity(0.15)),
                                shape: BoxShape.circle,
                            ),
                            child: Icon(
                                !hasBattery
                                    ? Icons.power
                                    : (isCharging ? Icons.bolt : Icons.timer_outlined),
                                color: !hasBattery
                                    ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F))
                                    : (isCharging ? Colors.amberAccent : const Color(0xFF00E5FF)),
                                size: 24,
                            ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        !hasBattery
                                            ? "給電状態"
                                            : (isCharging ? "充電完了予想時間" : "バッテリー残り稼働予想"),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white60 : Colors.black54,
                                        ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                        !hasBattery ? "🔌 外部電源駆動 (バッテリーレス)" : estimateStr,
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: !hasBattery
                                                ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F))
                                                : (isCharging ? Colors.amberAccent : (isDark ? Colors.white : Colors.black87)),
                                        ),
                                    ),
                                    if (hasBattery && signal?.isLongLifeCharging == true && isCharging) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                            signal?.batteryCapacity != null
                                                ? "※ いたわり充電有効中 (70%上限 / ${(signal!.batteryCapacity! * 0.70).round()}mAh で計算)"
                                                : "※ いたわり充電有効中 (70%上限で計算)",
                                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF00E5FF)),
                                        ),
                                    ],
                                ],
                            ),
                        ),
                    ],
                ),
            ),
        );
    }

    Widget _buildBatteryCard(SignalData? signal, bool isDark) {
        final hasBattery = signal?.isBatteryPresent ?? true;
        final rawPercent = signal?.batteryPercent;
        final scaledPercent = signal?.scaledBatteryPercent;
        final isLongLife = signal?.isLongLifeCharging ?? false;
        final temp = signal?.batteryTemperature;
        final volt = signal?.batteryVoltage;
        final curr = signal?.batteryCurrent;
        final cap = signal?.batteryCapacity;
        final chargeStatus = signal?.batteryChargeStatus ?? (signal?.isCharging == true ? "charging" : "discharging");

        // Current mAh calculation (dynamic from API, not hardcoded)
        final currentMah = (cap != null && rawPercent != null) ? ((cap * rawPercent) / 100).round() : null;

        return Card(
            color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                                const Row(
                                    children: [
                                        Icon(Icons.battery_std, size: 18, color: Color(0xFF4CAF50)),
                                        SizedBox(width: 6),
                                        Text(
                                            "バッテリー詳細ステータス",
                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                    ],
                                ),
                                if (hasBattery && isLongLife)
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFF00ADB5).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFF00ADB5), width: 0.8),
                                        ),
                                        child: Text(
                                            "いたわり充電 (70%制限)",
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F),
                                            ),
                                        ),
                                    ),
                            ],
                        ),
                        const SizedBox(height: 12),

                        if (!hasBattery)
                            Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
                                decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                                ),
                                child: Row(
                                    children: [
                                        Icon(Icons.power, size: 20, color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F)),
                                        const SizedBox(width: 10),
                                        Text(
                                            "バッテリー未装着 (AC給電駆動中)",
                                            style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? Colors.white : Colors.black87,
                                            ),
                                        ),
                                    ],
                                ),
                            )
                        else ...[
                            // Progress Bar for Battery
                            _buildProgressBarRow(
                                label: "残量",
                                valueText: isLongLife
                                    ? "${scaledPercent ?? '--'}% (実${rawPercent ?? '--'}%)"
                                    : "${rawPercent ?? '--'}%",
                                progress: (scaledPercent ?? rawPercent ?? 0) / 100.0,
                                progressColor: _getBatteryProgressColor(scaledPercent ?? rawPercent),
                                isDark: isDark,
                            ),
                            const Divider(height: 16),

                            // Metrics Grid
                            Row(
                                children: [
                                    Expanded(
                                        child: _buildMetricTile(
                                            label: "温度",
                                            value: temp != null ? "${temp.toStringAsFixed(1)} °C" : "--",
                                            color: _getTemperatureColor(temp, isDark),
                                            icon: Icons.thermostat,
                                            isDark: isDark,
                                        ),
                                    ),
                                    Expanded(
                                        child: _buildMetricTile(
                                            label: "電圧",
                                            value: volt != null ? "${(volt / 1000.0).toStringAsFixed(3)} V" : "--",
                                            subtitle: volt != null ? "(${volt.round()} mV)" : null,
                                            icon: Icons.electric_bolt,
                                            isDark: isDark,
                                        ),
                                    ),
                                ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                                children: [
                                    Expanded(
                                        child: _buildMetricTile(
                                            label: "電流 (入出力)",
                                            value: curr != null ? "${curr > 0 ? '+$curr' : curr} mA" : "--",
                                            subtitle: (currentMah != null && cap != null) ? "残容量: $currentMah / $cap mAh" : null,
                                            color: curr != null && curr > 0 ? (isDark ? Colors.amberAccent : Colors.orange.shade800) : null,
                                            icon: Icons.speed,
                                            isDark: isDark,
                                        ),
                                    ),
                                    Expanded(
                                        child: _buildMetricTile(
                                            label: "動作状態",
                                            value: chargeStatus == "charging"
                                                ? "充電中 (⚡)"
                                                : (chargeStatus == "discharging" ? "放電中 (バッテリー駆動)" : chargeStatus),
                                            icon: Icons.power,
                                            isDark: isDark,
                                        ),
                                    ),
                                ],
                            ),
                        ],
                    ],
                ),
            ),
        );
    }

    Widget _buildHardwareCard(SignalData? signal, bool isLoggedIn, bool isDark, BuildContext context) {
        final cpu = signal?.cpuUsagePercent;
        final totalRam = signal?.totalRamBytes;
        final usageRam = signal?.usageRamBytes;
        final procs = signal?.processCount;
        final uptime = signal?.formattedUptime ?? "--";
        final ramText = signal?.formattedRamUsage ?? "--";

        final ramRatio = (totalRam != null && totalRam > 0 && usageRam != null)
            ? (usageRam / totalRam).clamp(0.0, 1.0)
            : 0.0;

        return Card(
            color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        const Row(
                            children: [
                                Icon(Icons.memory, size: 18, color: Color(0xFF2196F3)),
                                SizedBox(width: 6),
                                Text(
                                    "ルーターハードウェア & システム状態",
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                            ],
                        ),
                        const SizedBox(height: 12),

                        if (!isLoggedIn) ...[
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                ),
                                child: Row(
                                    children: [
                                        Icon(Icons.lock_outline, size: 18, color: isDark ? Colors.amberAccent : Colors.orange.shade800),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text(
                                                "CPU・RAM・プロセス数・稼働時間はWebパスワード設定・ログイン時に取得されます",
                                                style: TextStyle(fontSize: 11.5, color: isDark ? Colors.amberAccent : Colors.orange.shade900),
                                            ),
                                        ),
                                        TextButton(
                                            onPressed: () {
                                                Navigator.of(context).pop();
                                                Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                                                );
                                            },
                                            child: const Text("設定へ", style: TextStyle(fontSize: 12)),
                                        ),
                                    ],
                                ),
                            ),
                            const SizedBox(height: 10),
                        ],

                        // CPU Progress Row
                        _buildProgressBarRow(
                            label: "CPU使用率",
                            valueText: cpu != null ? "$cpu %" : "--",
                            progress: (cpu ?? 0) / 100.0,
                            progressColor: _getCpuColor(cpu),
                            isDark: isDark,
                        ),
                        const Divider(height: 16),

                        // RAM Progress Row
                        _buildProgressBarRow(
                            label: "RAM使用率",
                            valueText: ramText,
                            progress: ramRatio,
                            progressColor: _getRamColor(ramRatio),
                            isDark: isDark,
                        ),
                        const Divider(height: 16),

                        // Processes and Uptime
                        Row(
                            children: [
                                Expanded(
                                    child: _buildMetricTile(
                                        label: "稼働時間",
                                        value: uptime,
                                        icon: Icons.access_time,
                                        isDark: isDark,
                                    ),
                                ),
                                Expanded(
                                    child: _buildMetricTile(
                                        label: "実行プロセス数",
                                        value: procs != null ? "$procs" : "--",
                                        icon: Icons.developer_board,
                                        isDark: isDark,
                                    ),
                                ),
                            ],
                        ),
                    ],
                ),
            ),
        );
    }

    Widget _buildProgressBarRow({
        required String label,
        required String valueText,
        required double progress,
        required Color progressColor,
        required bool isDark,
    }) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text(
                            valueText,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                    ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: isDark ? Colors.white10 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                ),
            ],
        );
    }

    Widget _buildMetricTile({
        required String label,
        required String value,
        String? subtitle,
        Color? color,
        IconData? icon,
        required bool isDark,
    }) {
        return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                if (icon != null) ...[
                    Icon(icon, size: 16, color: color ?? (isDark ? Colors.white54 : Colors.black54)),
                    const SizedBox(width: 6),
                ],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 1),
                            Text(
                                value,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: color ?? (isDark ? Colors.white : Colors.black87),
                                    fontFamily: 'monospace',
                                ),
                            ),
                            if (subtitle != null) ...[
                                const SizedBox(height: 1),
                                Text(
                                    subtitle,
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? Colors.white54 : Colors.black54,
                                        fontFamily: 'monospace',
                                    ),
                                ),
                            ],
                        ],
                    ),
                ),
            ],
        );
    }

    Color _getBatteryProgressColor(int? percent) {
        if (percent == null) return Colors.grey;
        if (percent >= 50) return const Color(0xFF4CAF50);
        if (percent >= 20) return Colors.amberAccent;
        return Colors.redAccent;
    }

    Color _getTemperatureColor(double? temp, bool isDark) {
        if (temp == null) return Colors.grey;
        if (temp >= 45) return Colors.redAccent;
        if (temp >= 40) return isDark ? Colors.amberAccent : Colors.orange.shade800;
        return isDark ? const Color(0xFF00E5FF) : const Color(0xFF00838F);
    }

    Color _getCpuColor(int? cpu) {
        if (cpu == null) return Colors.grey;
        if (cpu >= 80) return Colors.redAccent;
        if (cpu >= 50) return Colors.amberAccent;
        return const Color(0xFF2196F3);
    }

    Color _getRamColor(double ratio) {
        if (ratio >= 0.85) return Colors.redAccent;
        if (ratio >= 0.70) return Colors.amberAccent;
        return const Color(0xFF00ADB5);
    }
}

