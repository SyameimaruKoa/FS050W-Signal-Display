import 'package:flutter/foundation.dart';

enum LogLevel { info, warn, error, debug }

class LogEntry {
    final DateTime timestamp;
    final LogLevel level;
    final String message;
    final String? details;

    LogEntry({
        required this.timestamp,
        required this.level,
        required this.message,
        this.details,
    });

    String get formatted {
        final timeStr = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}";
        final lvlStr = level.name.toUpperCase().padRight(5);
        if (details != null && details!.isNotEmpty) {
            return "[$timeStr] [$lvlStr] $message\n  → $details";
        }
        return "[$timeStr] [$lvlStr] $message";
    }
}

class AppLogger {
    static final List<LogEntry> _logs = [];
    static const int maxLogs = 500;

    static void log(String message, {LogLevel level = LogLevel.info, String? details}) {
        final entry = LogEntry(
            timestamp: DateTime.now(),
            level: level,
            message: message,
            details: details,
        );

        _logs.add(entry);
        if (_logs.length > maxLogs) {
            _logs.removeRange(0, _logs.length - maxLogs);
        }

        if (kDebugMode) {
            debugPrint(entry.formatted);
        }
    }

    static void info(String message, [String? details]) => log(message, level: LogLevel.info, details: details);
    static void warn(String message, [String? details]) => log(message, level: LogLevel.warn, details: details);
    static void error(String message, [String? details]) => log(message, level: LogLevel.error, details: details);
    static void debug(String message, [String? details]) => log(message, level: LogLevel.debug, details: details);

    static List<LogEntry> get logs => List.unmodifiable(_logs);

    static void clear() {
        _logs.clear();
    }

    static String exportText() {
        final sb = StringBuffer();
        sb.writeln("=== FS050W Signal Display Diagnostic Log ===");
        sb.writeln("Export Time: ${DateTime.now().toIso8601String()}");
        sb.writeln("Total Entries: ${_logs.length}");
        sb.writeln("============================================\n");
        for (final entry in _logs) {
            sb.writeln(entry.formatted);
        }
        return sb.toString();
    }
}
