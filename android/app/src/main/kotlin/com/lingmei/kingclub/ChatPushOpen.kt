package com.lingmei.kingclub

import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/** Accept only the documented string extra; Flutter validates and authorizes it. */
class ChatPushOpen(private val channel: MethodChannel) {
    private val pending = ArrayDeque<String>()
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method == "takePending") result.success(pending.pollFirst())
            else result.notImplemented()
        }
    }
    fun accept(intent: Intent?) {
        val raw = try { intent?.getStringExtra("kingclub_push") } catch (_: Exception) { null }
        if (raw == null || raw.length > 2048 || raw.isBlank()) return
        // Do not redeliver the same intent on Activity recreation.
        intent?.removeExtra("kingclub_push")
        if (pending.contains(raw)) return
        if (pending.size >= 8) pending.removeFirst()
        pending.addLast(raw)
        channel.invokeMethod("changed", null)
    }
    fun close() {
        pending.clear()
        channel.setMethodCallHandler(null)
    }
}
