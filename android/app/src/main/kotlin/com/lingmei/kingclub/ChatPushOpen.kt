package com.lingmei.kingclub

import android.content.Intent
import android.content.Context
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Accept only the documented string extra; Flutter validates and authorizes it. */
class ChatPushOpen(context: Context, private val channel: MethodChannel) {
    private val store = ChatPushPendingStore(context)
    private fun read(): MutableList<String> {
        val saved = store.read()
        val valid = saved.filter { normalize(it) != null }.toMutableList()
        if (valid.size != saved.size) store.write(valid)
        return valid
    }

    private fun normalize(raw: String): String? = try {
        if (raw.length > 2048) null else {
            val value = JSONObject(raw)
            val expiry = value.getLong("expiresAt")
            val now = System.currentTimeMillis()
            val scope = value.getString("scope")
            val kind = value.getString("kind")
            val uuid = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
            val account = Regex("^[A-Za-z0-9_-]{1,64}$")
            if (value.getInt("version") != 1 || scope !in listOf("direct", "group") ||
                kind !in listOf("message", "call") || expiry <= now || expiry > now + 86400000L ||
                !uuid.matches(value.getString("eventId")) || !account.matches(value.getString("recipient")) ||
                !(if (scope == "group") uuid else account).matches(value.getString("target"))) null
            else JSONObject().apply {
                for (field in listOf("version", "eventId", "recipient", "target", "scope", "kind", "expiresAt"))
                    put(field, value.get(field))
            }.toString()
        }
    } catch (_: Exception) { null }
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                if (call.method == "takePending") {
                    val pending = read()
                    result.success(pending.firstOrNull())
                } else if (call.method == "ackPending") {
                    val pending = read()
                    val raw = call.arguments as? String
                    if (pending.firstOrNull() == raw) {
                        pending.removeAt(0)
                        store.write(pending)
                    }
                    result.success(null)
                } else result.notImplemented()
            } catch (_: Exception) {
                result.error("PUSH_PENDING_STORAGE", "Notification recovery storage unavailable", null)
            }
        }
    }
    fun accept(intent: Intent?) {
        val raw = try { intent?.getStringExtra("kingclub_push") } catch (_: Exception) { null }
        if (raw == null) return
        val normalized = normalize(raw) ?: run { intent?.removeExtra("kingclub_push"); return }
        try {
            val pending = read()
            if (!pending.contains(normalized)) {
                if (pending.size >= 8) pending.removeAt(0)
                pending.add(normalized)
            }
            store.write(pending)
            // Remove only after an atomic encrypted journal write succeeds.
            intent?.removeExtra("kingclub_push")
            channel.invokeMethod("changed", null)
        } catch (_: Exception) {
            // Retain the Intent so onResume can retry a transient Keystore failure.
        }
    }
    fun close() {
        channel.setMethodCallHandler(null)
    }
}
