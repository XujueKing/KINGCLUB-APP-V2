package com.lingmei.kingclub

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Notifications while Flutter's authenticated background connection is alive.
 * Never starts media capture or bypasses OS notification preferences. */
class ChatLocalNotifications(private val context: Context) {
    private val manager = context.getSystemService(NotificationManager::class.java)
    private var session: String? = null
    private val prefix = "kingclub-local:"
    private fun clear(callsOnly: Boolean = false) {
        if (Build.VERSION.SDK_INT >= 23) manager.activeNotifications
            .filter { it.tag?.startsWith(prefix) == true &&
                (!callsOnly || it.notification.category == Notification.CATEGORY_CALL) }
            .forEach { manager.cancel(it.tag, it.id) }
    }
    fun handle(call: MethodCall, result: MethodChannel.Result, foreground: Boolean) {
        try {
            when (call.method) {
                "bind" -> {
                    val next = call.argument<String>("session")
                    if (session != next || next == null) { clear(); session = next }
                    result.success(null)
                }
                "reconcileCalls" -> {
                    if (session != null && session == call.argument<String>("session")) {
                        val scope = call.argument<String>("scope")
                        val live = call.argument<List<String>>("live") ?: emptyList()
                        if (Build.VERSION.SDK_INT >= 23) manager.activeNotifications
                            .filter { it.tag?.startsWith(prefix) == true &&
                                it.notification.category == Notification.CATEGORY_CALL &&
                                it.notification.extras.getString("kingclub_scope") == scope &&
                                it.notification.extras.getString("kingclub_event") !in live }
                            .forEach { manager.cancel(it.tag, it.id) }
                    }
                    result.success(null)
                }
                "clearCalls" -> { clear(true); result.success(null) }
                "clear" -> { clear(); result.success(null) }
                "show" -> {
                    if (foreground || session == null || session != call.argument<String>("session")) {
                        result.success(false); return
                    }
                    val raw = call.argument<String>("destination") ?: error("destination")
                    require(raw.length <= 2048)
                    val value = JSONObject(raw)
                    val expiry = value.getLong("expiresAt")
                    val remaining = expiry - System.currentTimeMillis()
                    if (remaining <= 0 || remaining > 86400000L || !manager.areNotificationsEnabled()) {
                        result.success(false); return
                    }
                    val isCall = value.getString("kind") == "call"
                    val channel = if (isCall) "kingclub_live_calls_v1" else "kingclub_live_messages_v1"
                    if (Build.VERSION.SDK_INT >= 26) {
                        manager.createNotificationChannel(NotificationChannel(channel,
                            if (isCall) "语音和视频来电" else "聊天消息提醒",
                            NotificationManager.IMPORTANCE_HIGH).apply {
                            description = if (isCall) "真实好友及群聊来电邀请" else "好友和群聊的新消息"
                            setShowBadge(true)
                        })
                    }
                    val tag = prefix + value.getString("scope") + ":" +
                        value.getString("target") + ":" + value.getString("kind")
                    val intent = Intent(context, MainActivity::class.java)
                        .setData(Uri.parse("kingclub://notification/" + Uri.encode(tag)))
                        .putExtra("kingclub_push", raw)
                        .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    val open = PendingIntent.getActivity(context, 0, intent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, channel)
                        else Notification.Builder(context)
                    builder.setSmallIcon(if (isCall) android.R.drawable.stat_sys_phone_call else android.R.drawable.stat_notify_chat)
                        .setContentTitle("KINGCLUB")
                        .setContentText(if (isCall) "你有一个通话邀请，点击查看" else "你收到了一条新消息")
                        .setContentIntent(open).setAutoCancel(true)
                        .setOnlyAlertOnce(isCall)
                        .setCategory(if (isCall) Notification.CATEGORY_CALL else Notification.CATEGORY_MESSAGE)
                        .setVisibility(Notification.VISIBILITY_PRIVATE)
                        .setNumber((call.argument<Int>("unread") ?: 1).coerceIn(1, 9999))
                        .setPriority(Notification.PRIORITY_HIGH)
                    if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(remaining)
                    builder.addExtras(android.os.Bundle().apply {
                        putString("kingclub_scope", value.getString("scope"))
                        putString("kingclub_event", value.getString("eventId"))
                    })
                    manager.notify(tag, 4280, builder.build())
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("LOCAL_NOTIFICATION_FAILED", "Local notification unavailable", null)
        }
    }
}
