package com.syameimarukoa.fs050w_signal_display.ui

import androidx.compose.runtime.staticCompositionLocalOf
import com.syameimarukoa.fs050w_signal_display.data.SignalRepository

val LocalRepository = staticCompositionLocalOf<SignalRepository> {
    error("SignalRepository is not provided in this composition")
}
