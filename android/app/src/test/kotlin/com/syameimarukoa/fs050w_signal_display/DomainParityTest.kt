package com.syameimarukoa.fs050w_signal_display

import com.syameimarukoa.fs050w_signal_display.domain.model.AppSettings
import com.syameimarukoa.fs050w_signal_display.domain.model.AppThemeMode
import com.syameimarukoa.fs050w_signal_display.domain.model.Fs050wConnectionMode
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalRatingLevel
import com.syameimarukoa.fs050w_signal_display.domain.model.SignalData
import com.syameimarukoa.fs050w_signal_display.domain.util.ColorGauge
import com.syameimarukoa.fs050w_signal_display.domain.util.CryptoUtils
import com.syameimarukoa.fs050w_signal_display.domain.util.FrequencyCalculator
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Behavioural parity checks ported from the original Dart unit tests. */
class DomainParityTest {

    @Test
    fun passwordHashIsHexAndStable() {
        val hash = CryptoUtils.computeLoginPasswordHash("password123", "abc123prikey")
        assertEquals(32, hash.length)
        assertTrue(hash.matches(Regex("[0-9a-f]{32}")))
        assertEquals(hash, CryptoUtils.computeLoginPasswordHash("password123", "abc123prikey"))
    }

    @Test
    fun signalRatingThresholds() {
        assertEquals(SignalRatingLevel.EXCELLENT, ColorGauge.rateRsrp(-79.0))
        assertEquals(SignalRatingLevel.GOOD, ColorGauge.rateRsrp(-85.0))
        assertEquals(SignalRatingLevel.MODERATE, ColorGauge.rateRsrp(-95.0))
        assertEquals(SignalRatingLevel.WEAK, ColorGauge.rateRsrp(-105.0))
        assertEquals(SignalRatingLevel.VERY_WEAK, ColorGauge.rateRsrp(-115.0))
        assertEquals(SignalRatingLevel.CRITICAL, ColorGauge.rateRsrp(-125.0))
        assertEquals(SignalRatingLevel.UNKNOWN, ColorGauge.rateRsrp(null))
        assertEquals(0xFF2196F3L, ColorGauge.colorFor(SignalRatingLevel.EXCELLENT))
        assertEquals(0xFF9C27B0L, ColorGauge.colorFor(SignalRatingLevel.CRITICAL))
    }

    @Test
    fun curveAndSmoothColorBoundaries() {
        assertEquals(0.0, ColorGauge.applyCurve(0.0, "easeOut"), 0.0001)
        assertEquals(1.0, ColorGauge.applyCurve(1.0, "easeOut"), 0.0001)
        assertEquals(0.75, ColorGauge.applyCurve(0.5, "easeOut"), 0.0001)
        assertEquals(ColorGauge.COLOR_CRITICAL, ColorGauge.getSmoothColor(0.0, "linear"))
        assertEquals(ColorGauge.COLOR_EXCELLENT, ColorGauge.getSmoothColor(1.0, "linear"))
    }

    @Test
    fun bandNamesAndSub6Detection() {
        assertEquals("B3 (1.7GHz)", FrequencyCalculator.getLteBandName(3))
        assertEquals("n78 (3.7GHz)", FrequencyCalculator.getNrBandName(78))
        assertTrue(FrequencyCalculator.isSub6Band(78))
        assertTrue(FrequencyCalculator.isRefarmed5gBand(28))
        assertEquals("楽天回線", FrequencyCalculator.getLteBadgeText(3, "Rakuten"))
    }

    @Test
    fun lteParsingConvertsRawValues() {
        val json = JSONObject()
            .put("mnet_sysmode", "lte")
            .put("mnet_rsrp", 68)
            .put("mnet_rsrq", 63)
            .put("mnet_wnw_band", 3)
            .put("mnet_wnw_pci", 315)
        val signal = SignalData.fromApiResponse(json)
        assertEquals(Fs050wConnectionMode.LTE, signal.connectionMode)
        assertEquals(-73.0, signal.lteRsrp!!, 0.0001)
        assertEquals(11.5, signal.lteRsrq!!, 0.0001)
        assertEquals(315, signal.ltePci)
        assertNull(signal.nrRsrp)
    }

    @Test
    fun saUsesNrConversionAndHidesAnchor() {
        val json = JSONObject()
            .put("mnet_sysmode", "nr5g")
            .put("mnet_rsrp", 68)
            .put("mnet_wnw_band", 78)
        val signal = SignalData.fromApiResponse(json)
        assertTrue(signal.isSa)
        assertEquals(Fs050wConnectionMode.NR5G_SUB6, signal.connectionMode)
        assertEquals(-89.0, signal.nrRsrp!!, 0.0001)
    }

    @Test
    fun snrAdjustmentAndHandoverDetection() {
        val first = JSONObject()
            .put("mnet_sysmode", "nsa")
            .put("mnet_rsrp", 71)
            .put("mnet_wnw_pci", 29)
            .put("mnet_endc_rsrp", 68)
            .put("mnet_endc_snr", 76)
            .put("mnet_wnw_psband", 78)
            .put("mnet_wnw_pspci", 100)
        val previous = SignalData.fromApiResponse(first, adjust5gSnr = true)
        assertEquals(14.5, previous.nrSnr!!, 0.0001) // ((76-1)/2)-23

        val second = JSONObject()
            .put("mnet_sysmode", "nsa")
            .put("mnet_rsrp", 71)
            .put("mnet_wnw_pci", 29)
            .put("mnet_endc_rsrp", 68)
            .put("mnet_endc_snr", 76)
            .put("mnet_wnw_psband", 78)
            .put("mnet_wnw_pspci", 200)
        val next = SignalData.fromApiResponse(second, previousData = previous, adjust5gSnr = true)
        assertTrue(next.handoverDescription!!.startsWith("5G PCI 100 → 200"))
    }

    @Test
    fun batteryLessSanitizesBatteryMetrics() {
        val json = JSONObject()
            .put("mnet_sysmode", "lte")
            .put("device_battery_exist", "0")
            .put("device_battery_level_percent", 90)
            .put("device_battery_temperature", 40)
        val signal = SignalData.fromApiResponse(json)
        assertEquals(false, signal.isBatteryPresent)
        assertNull(signal.batteryPercent)
        assertNull(signal.batteryTemperature)
    }

    @Test
    fun settingsJsonRoundTrip() {
        val settings = AppSettings(
            routerIp = "192.168.100.1",
            webPassword = "secret",
            appTheme = AppThemeMode.OLED,
            batteryTempWarningThreshold = 42.5,
            overlayEnabled = true,
            pipAspectRatio = "9:16",
        )
        val restored = AppSettings.fromJson(JSONObject(settings.toJson().toString()))
        assertEquals(settings, restored)
    }
}
