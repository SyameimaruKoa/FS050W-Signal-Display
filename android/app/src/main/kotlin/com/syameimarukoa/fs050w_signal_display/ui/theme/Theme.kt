package com.syameimarukoa.fs050w_signal_display.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ColorScheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
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

// Flutter 版の ColorScheme と同じブランドカラー。
private val BrandPrimary = Color(0xFF00ADB5)
private val BrandSecondary = Color(0xFF00E5FF)

private val DarkScheme = darkColorScheme(
    primary = BrandPrimary,
    onPrimary = Color(0xFF000000),
    secondary = BrandSecondary,
    onSecondary = Color(0xFF000000),
    tertiary = BrandSecondary,
    background = Color(0xFF121212),
    onBackground = Color(0xFFE0E0E0),
    surface = Color(0xFF1E1E1E),
    onSurface = Color(0xFFE0E0E0),
    surfaceContainerLowest = Color(0xFF0E0E0E),
    surfaceContainerLow = Color(0xFF171717),
    surfaceContainer = Color(0xFF1E1E1E),
    surfaceContainerHigh = Color(0xFF252525),
    surfaceContainerHighest = Color(0xFF2D2D2D),
)

private val OledScheme = DarkScheme.copy(
    background = Color.Black,
    onBackground = Color(0xFFE0E0E0),
    surface = Color(0xFF111111),
    surfaceContainerLowest = Color.Black,
    surfaceContainerLow = Color(0xFF050505),
    surfaceContainer = Color(0xFF0A0A0A),
    surfaceContainerHigh = Color(0xFF101010),
    surfaceContainerHighest = Color(0xFF161616),
)

private val LightScheme = lightColorScheme(
    primary = Color(0xFF007A78),
    onPrimary = Color.White,
    secondary = BrandPrimary,
    onSecondary = Color.White,
    tertiary = BrandPrimary,
    background = Color(0xFFF8F9FA),
    onBackground = Color(0xFF1A1A1A),
    surface = Color.White,
    onSurface = Color(0xFF1A1A1A),
    surfaceContainerLowest = Color.White,
    surfaceContainerLow = Color(0xFFF5F5F5),
    surfaceContainer = Color(0xFFF0F0F0),
    surfaceContainerHigh = Color(0xFFE8E8E8),
    surfaceContainerHighest = Color(0xFFE0E0E0),
)

@Composable
fun Fs050wTheme(settings: AppSettings, content: @Composable () -> Unit) {
    val systemDark = isSystemInDarkTheme()
    val scheme: ColorScheme = when (settings.appTheme) {
        AppThemeMode.OLED -> OledScheme
        AppThemeMode.DARK -> DarkScheme
        AppThemeMode.LIGHT -> LightScheme
        AppThemeMode.SYSTEM -> if (systemDark) DarkScheme else LightScheme
    }
    MaterialTheme(colorScheme = scheme, typography = AppTypography, content = content)
}
