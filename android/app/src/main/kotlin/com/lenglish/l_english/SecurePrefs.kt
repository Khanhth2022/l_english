package com.lenglish.l_english

import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Mã hoá access token của Widget bằng khoá AES/GCM nằm trong Android Keystore.
 *
 * SharedPreferences thường lưu plaintext, nên thiết bị bị root hoặc adb backup
 * có thể đọc được token. Khoá ở đây không xuất khỏi Keystore.
 */
object SecurePrefs {
    private const val KEY_ALIAS = "lenglish_widget_token_key"
    private const val KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val IV_BYTES = 12
    private const val TAG_BITS = 128

    fun putToken(prefs: SharedPreferences, token: String) {
        val editor = prefs.edit()
        if (token.isEmpty()) {
            editor.remove(DueWordsWidgetProvider.KEY_ACCESS_TOKEN)
        } else {
            editor.putString(
                DueWordsWidgetProvider.KEY_ACCESS_TOKEN,
                encrypt(token)
            )
        }
        editor.apply()
    }

    fun getToken(prefs: SharedPreferences): String? {
        val stored = prefs.getString(DueWordsWidgetProvider.KEY_ACCESS_TOKEN, null)
            ?: return null
        return decrypt(stored)
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        val existing = keyStore.getEntry(KEY_ALIAS, null) as? KeyStore.SecretKeyEntry
        if (existing != null) return existing.secretKey

        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build()
        )
        return generator.generateKey()
    }

    private fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val encrypted = cipher.doFinal(plain.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(cipher.iv + encrypted, Base64.NO_WRAP)
    }

    private fun decrypt(encoded: String): String? {
        return try {
            val payload = Base64.decode(encoded, Base64.NO_WRAP)
            if (payload.size <= IV_BYTES) {
                null
            } else {
                val iv = payload.copyOfRange(0, IV_BYTES)
                val body = payload.copyOfRange(IV_BYTES, payload.size)
                val cipher = Cipher.getInstance(TRANSFORMATION)
                cipher.init(
                    Cipher.DECRYPT_MODE,
                    getOrCreateKey(),
                    GCMParameterSpec(TAG_BITS, iv)
                )
                String(cipher.doFinal(body), Charsets.UTF_8)
            }
        } catch (_: Exception) {
            // Token cũ dạng plaintext hoặc khoá đã bị xoá: coi như chưa có token.
            null
        }
    }
}
