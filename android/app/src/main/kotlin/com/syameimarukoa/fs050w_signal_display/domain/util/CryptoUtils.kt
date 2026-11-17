package com.syameimarukoa.fs050w_signal_display.domain.util

import java.util.Locale
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.security.MessageDigest

/** Port of the router's challenge-response password hash (HMAC-MD5 chain). */
object CryptoUtils {
    private const val DEFAULT_KEY = "0123456789"
    private const val PREFIX = "4cc68e3626e5b94602c325f7c4ca5dee:example.com:"
    const val USERNAME = "4cc68e3626e5b94602c325f7c4ca5dee"

    fun computeLoginPasswordHash(password: String, prikey: String): String {
        val h1 = hmacMd5Hex(DEFAULT_KEY, password)
        val p1 = md5Hex(PREFIX + h1)
        return hmacMd5Hex(DEFAULT_KEY, p1 + prikey)
    }

    private fun hmacMd5Hex(key: String, data: String): String {
        val mac = Mac.getInstance("HmacMD5")
        mac.init(SecretKeySpec(key.toByteArray(Charsets.UTF_8), "HmacMD5"))
        return mac.doFinal(data.toByteArray(Charsets.UTF_8)).toHex()
    }

    private fun md5Hex(data: String): String =
        MessageDigest.getInstance("MD5").digest(data.toByteArray(Charsets.UTF_8)).toHex()

    private fun ByteArray.toHex(): String = joinToString("") { "%02x".format(Locale.ROOT, it) }
}
