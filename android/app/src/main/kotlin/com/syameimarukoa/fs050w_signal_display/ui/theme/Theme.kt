package com.syameimarukoa.fs050w_signal_display.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.model.AppThemeMode

val AppTypography = Typography().let { base ->
    val mono = base.bodyMedium.copy(fontFamily = FontFamily.Monospace)
    base.copy(
        bodyMedium = mono,
        bodySmall = base.bodySmall.copy(fontFamily = FontFamily.Monospace),
        titleMedium = base.titleMedium.copy(fontFamily = FontFamily.Monospace),
        labelMedium = base.labelMedium.copy(fontFamily = FontFamily.Monospace),
    )
}

@Composable
fun Fs050wTheme(settings: AppSettings, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val systemDark = isSystemInDarkTheme()
    val dark = when (settings.appTheme) {
        AppThemeMode.OLED, AppThemeMode.DARK -> true
        AppThemeMode.LIGHT -> false
        AppThemeMode.SYSTEM -> systemDark
    }

    val scheme = when {
        settings.appTheme == AppThemeMode.OLED -> dynamicDarkColorScheme(context).copy(
            background = Color.Black,
            surface = Color.Black,
            surfaceContainerLowest = Color.Black,
            surfaceContainerLow = Color(0xFF050505),
            surfaceContainer = Color(0xFF0A0A0A),
            surfaceContainerHigh = Color(0xFF101010),
            surfaceContainerHighest = Color(0xFF161616),
        )
        dark -> dynamicDarkColorScheme(context)
        else -> dynamicLightColorScheme(context)
    }

    // dynamic*ColorScheme already falls back to the platform baseline (minSdk 33).
    MaterialTheme(colorScheme = scheme, typography = AppTypography, content = content)
}
