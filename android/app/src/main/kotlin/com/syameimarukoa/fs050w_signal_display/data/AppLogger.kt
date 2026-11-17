package com.syameimarukoa.fs050w_signal_display.data

import android.util.Log
import java.time.LocalDateTime

enum class LogLevel { INFO, WARN, ERROR, DEBUG }

data class LogEntry(
    val timestamp: LocalDateTime = LocalDateTime.now(),
    val level: LogLevel,
    val message: String,
    val details: String? = null,
) {
    val formatted: String
        get() {
            val time = SignalDataTimeFormatter.format(timestamp)
            val lvl = level.name.padEnd(5)
            return if (!details.isNullOrEmpty()) "[$time] [$lvl] $message\n  → $details"
            else "[$time] [$lvl] $message"
        }
}

private val SignalDataTimeFormatter = java.time.format.DateTimeFormatter.ofPattern("HH:mm:ss.SSS")

object AppLogger {
    private const val MAX_LOGS = 500
    private val logs = mutableListOf<LogEntry>()

    @Synchronized
    fun log(message: String, level: LogLevel = LogLevel.INFO, details: String? = null) {
        val entry = LogEntry(level = level, message = message, details = details)
        logs.add(entry)
        if (logs.size > MAX_LOGS) logs.removeAt(0)
        val tag = "FS050W"
        when (level) {
            LogLevel.INFO -> Log.i(tag, entry.formatted)
            LogLevel.WARN -> Log.w(tag, entry.formatted)
            LogLevel.ERROR -> Log.e(tag, entry.formatted)
            LogLevel.DEBUG -> Log.d(tag, entry.formatted)
        }
    }

    fun info(message: String, details: String? = null) = log(message, LogLevel.INFO, details)
    fun warn(message: String, details: String? = null) = log(message, LogLevel.WARN, details)
    fun error(message: String, details: String? = null) = log(message, LogLevel.ERROR, details)
    fun debug(message: String, details: String? = null) = log(message, LogLevel.DEBUG, details)

    @Synchronized
    fun entries(): List<LogEntry> = logs.toList()

    @Synchronized
    fun clear() = logs.clear()

    @Synchronized
    fun exportText(): String = buildString {
        appendLine("=== FS050W Signal Display Diagnostic Log ===")
        appendLine("Export Time: ${java.time.LocalDateTime.now()}")
        appendLine("Total Entries: ${logs.size}")
        appendLine("============================================")
        appendLine()
        logs.forEach { appendLine(it.formatted) }
    }
}
