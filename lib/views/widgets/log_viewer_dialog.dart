import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_logger.dart';

class LogViewerDialog extends StatefulWidget {
    const LogViewerDialog({super.key});

    static void show(BuildContext context) {
        showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: const Color(0xFF1E1E1E),
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
                        decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white12)),
                        ),
                        child: Row(
                            children: [
                                const Icon(Icons.assignment, color: Colors.cyanAccent, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        "アプリ診断ログ (${logs.length}件)",
                                        style: GoogleFonts.notoSansJp(fontWeight: FontWeight.bold, fontSize: 15),
                                        overflow: TextOverflow.ellipsis,
                                    ),
                                ),
                                IconButton(
                                    icon: const Icon(Icons.copy, color: Colors.greenAccent, size: 20),
                                    tooltip: "全ログをクリップボードにコピー",
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                        Clipboard.setData(ClipboardData(text: AppLogger.exportText()));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text("ログをクリップボードにコピーしました")),
                                        );
                                    },
                                ),
                                IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    tooltip: "ログをクリア",
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                        setState(() {
                                            AppLogger.clear();
                                        });
                                    },
                                ),
                                IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => Navigator.of(context).pop(),
                                ),
                            ],
                        ),

                    ),

                    // Filter Search Box
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: TextField(
                            decoration: InputDecoration(
                                hintText: "ログ内を検索 (エラー, retcode, IP...)",
                                prefixIcon: const Icon(Icons.search, size: 18),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.05),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                ),
                            ),
                            onChanged: (v) => setState(() => _filter = v.trim()),
                        ),
                    ),

                    // Log List
                    Expanded(
                        child: logs.isEmpty
                            ? const Center(
                                child: Text("ログはありません", style: TextStyle(color: Colors.white38)),
                            )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                itemCount: logs.length,
                                itemBuilder: (ctx, index) {
                                    final entry = logs[logs.length - 1 - index]; // latest first
                                    Color levelColor = Colors.white70;
                                    if (entry.level == LogLevel.error) levelColor = Colors.redAccent;
                                    if (entry.level == LogLevel.warn) levelColor = Colors.orangeAccent;
                                    if (entry.level == LogLevel.debug) levelColor = Colors.blueAccent;

                                    return Container(
                                        margin: const EdgeInsets.only(bottom: 6),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.white10),
                                        ),
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Row(
                                                    children: [
                                                        Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                            decoration: BoxDecoration(
                                                                color: levelColor.withOpacity(0.2),
                                                                borderRadius: BorderRadius.circular(3),
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
                                                            style: GoogleFonts.notoSansMono(
                                                                fontSize: 11,
                                                                color: Colors.white38,
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                                const SizedBox(height: 4),
                                                SelectableText(
                                                    entry.message,
                                                    style: GoogleFonts.notoSansMono(fontSize: 12, color: Colors.white),
                                                ),
                                                if (entry.details != null && entry.details!.isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    SelectableText(
                                                        entry.details!,
                                                        style: GoogleFonts.notoSansMono(fontSize: 11, color: Colors.white60),
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
