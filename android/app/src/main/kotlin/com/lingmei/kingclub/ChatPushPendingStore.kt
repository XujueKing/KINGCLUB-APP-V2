package com.lingmei.kingclub

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONArray
import org.json.JSONException
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.AEADBadTagException
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Short-lived routing hints only. Excluded from backup; never stores message bodies. */
class ChatPushPendingStore(context: Context) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "chat-push-pending-v1"))
    private val alias = "kingclub.chat.push-pending.v1"
    private class CorruptJournal : Exception()

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = store.getKey(alias, null)
        if (existing is SecretKey) return existing
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).build())
        }.generateKey()
    }

    fun read(): List<String> {
        try {
            val bytes = try {
                file.openRead().use {
                    // Check before allocation, including a truncated/interrupted file.
                    if (it.channel.size() !in 29L..32768L) throw CorruptJournal()
                    it.readBytes()
                }
            } catch (_: java.io.FileNotFoundException) { return emptyList() }
            if (bytes.size !in 29..32768) throw CorruptJournal()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            cipher.updateAAD(alias.toByteArray(Charsets.UTF_8))
            val array = JSONArray(String(cipher.doFinal(bytes, 12, bytes.size - 12), Charsets.UTF_8))
            if (array.length() > 8) throw CorruptJournal()
            return (0 until array.length()).map {
                val raw = array.get(it)
                if (raw !is String || raw.length > 2048) throw CorruptJournal()
                raw
            }
        } catch (_: CorruptJournal) {
            return discardCorruptJournal()
        } catch (_: AEADBadTagException) {
            return discardCorruptJournal()
        } catch (_: JSONException) {
            return discardCorruptJournal()
        }
        // I/O and Keystore availability failures propagate. They must not erase
        // an otherwise valid destination just because storage is temporarily locked.
    }

    private fun discardCorruptJournal(): List<String> {
        file.delete()
        return emptyList()
    }

    fun write(items: List<String>) {
        require(items.size <= 8 && items.all { it.length <= 2048 })
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        cipher.updateAAD(alias.toByteArray(Charsets.UTF_8))
        val bytes = cipher.iv + cipher.doFinal(JSONArray(items).toString().toByteArray(Charsets.UTF_8))
        val stream = file.startWrite()
        try {
            stream.write(bytes)
            file.finishWrite(stream)
        } catch (error: Exception) {
            file.failWrite(stream)
            throw error
        }
    }
}
