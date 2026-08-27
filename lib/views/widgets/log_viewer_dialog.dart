import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_logger.dart';

class LogViewerDialog extends StatefulWidget {
    const LogViewerDialog({super.key});

    static void show(BuildContext context) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Theme.of(context).cardColor,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            builder: (_) => const LogViewerDialog(),
        );
    }

    @override
    State<LogViewerDialog> createState() => _LogViewerDialogState();
}

class _LogViewerDialogState extends State<LogViewerDialog> {
    final ScrollController _scrollController = ScrollController();
    String _filter = "";

    @override
    void dispose() {
        _scrollController.dispose();
        super.dispose();
    }

    @override
    Widget build(BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final logs = AppLogger.logs.where((l) {
            if (_filter.isEmpty) return true;
            return l.formatted.toLowerCase().contains(_filter.toLowerCase());
        }).toList();

        return SizedBox(
            height: MediaQuery.of(context).size.height * 0.85,
            child: Column(
                children: [
                    // Header
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                        ),
                        child: Row(
                            children: [
                                Icon(Icons.assignment, color: isDark ? Colors.cyanAccent : const Color(0xFF007A78), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        "アプリ診断ログ (${logs.length}件)",
                                        style: TextStyle(
                                            fontFamilyFallback: const ['Noto Sans JP', 'sans-serif'],
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 20),
                                    tooltip: "全ログをクリップボードにコピー",
                                    onPressed: () {
                                        final text = AppLogger.exportText();
                                        Clipboard.setData(ClipboardData(text: text));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                                content: Text("診断ログをクリップボードにコピーしました"),
                                                duration: Duration(seconds: 2),
                                            ),
                                        );
                                    },
                                ),
                                IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: "ログをクリア",
                                    onPressed: () {
                                        setState(() {
                                            AppLogger.clear();
                                        });
                                    },
                                ),
                                IconButton(
                                    icon: const Icon(Icons.close, size: 20),
                                    onPressed: () => Navigator.of(context).pop(),
                                ),
                            ],
                        ),
                    ),
                    // Search bar
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                            decoration: InputDecoration(
                                hintText: "ログ内を検索...",
                                prefixIcon: const Icon(Icons.search, size: 18),
                                suffixIcon: _filter.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () => setState(() => _filter = ""),
                                    )
                                    : null,
                                isDense: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                ),
                            ),
                            onChanged: (val) => setState(() => _filter = val),
                        ),
                    ),
                    // Log entries list
                    Expanded(
                        child: logs.isEmpty
                            ? Center(
                                child: Text(
                                    _filter.isEmpty ? "ログはありません" : "一致するログが見つかりません",
                                    style: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                                ),
                            )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                itemCount: logs.length,
                                itemBuilder: (context, index) {
                                    final entry = logs[index];
                                    Color levelColor;
                                    Color levelBg;
                                    switch (entry.level) {
                                        case LogLevel.error:
                                            levelColor = Colors.redAccent;
                                            levelBg = Colors.redAccent.withOpacity(0.15);
                                            break;
                                        case LogLevel.warn:
                                            levelColor = Colors.amberAccent;
                                            levelBg = Colors.amberAccent.withOpacity(0.15);
                                            break;
                                        case LogLevel.debug:
                                            levelColor = Colors.blueAccent;
                                            levelBg = Colors.blueAccent.withOpacity(0.15);
                                            break;
                                        case LogLevel.info:
                                            levelColor = Colors.greenAccent;
                                            levelBg = Colors.greenAccent.withOpacity(0.15);
                                            break;
                                    }

                                    return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 3),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                                color: isDark ? Colors.white10 : Colors.black12,
                                                width: 0.5,
                                            ),
                                        ),
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                            decoration: BoxDecoration(
                                                                color: levelBg,
                                                                borderRadius: BorderRadius.circular(4),
                                                            ),
                                                            child: Text(
                                                                entry.level.name.toUpperCase(),
                                                                style: TextStyle(
                                                                    fontSize: 10,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: levelColor,
                                                                ),
                                                            ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                            "${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}:${entry.timestamp.second.toString().padLeft(2, '0')}.${entry.timestamp.millisecond.toString().padLeft(3, '0')}",
                                                            style: const TextStyle(
                                                                fontFamily: 'monospace',
                                                                fontSize: 11,
                                                                color: Colors.grey,
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                                const SizedBox(height: 4),
                                                SelectableText(
                                                    entry.message,
                                                    style: TextStyle(
                                                        fontFamily: 'monospace',
                                                        fontSize: 12,
                                                        color: isDark ? Colors.white : Colors.black87,
                                                    ),
                                                ),
                                                if (entry.details != null && entry.details!.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    SelectableText(
                                                        entry.details!,
                                                        style: TextStyle(
                                                            fontFamily: 'monospace',
                                                            fontSize: 11,
                                                            color: isDark ? Colors.white60 : Colors.black54,
                                                        ),
                                                    ),
                                                ],
                                            ],
                                        ),
                                    );
                                },
                            ),
                    ),
                ],
            ),
        );
    }
}
