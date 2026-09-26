package com.lingmei.kingclub

import android.content.Context
import android.content.Intent
import android.app.NotificationManager
import android.app.NotificationChannel
import android.os.Build
import android.provider.Settings
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.heytap.msp.push.HeytapPushManager
import com.heytap.msp.push.callback.ICallBackResultService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Registers only after an explicit foreground request; never logs credentials or tokens. */
class ChatPushRegistration(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var timeout: Runnable? = null
    private var closed = false

    fun handle(call: MethodCall, result: MethodChannel.Result, foreground: Boolean) {
        if (call.method == "notificationStatus") {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            result.success(manager.areNotificationsEnabled())
            return
        }
        if (call.method == "openNotificationSettings") {
            if (closed || !foreground) {
                result.error("PUSH_BACKGROUND", "Open the app before changing notifications", null)
                return
            }
            try {
                val intent = if (Build.VERSION.SDK_INT >= 26) {
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                } else {
                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        Uri.parse("package:${context.packageName}"))
                }
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                result.success(null)
            } catch (_: Exception) {
                result.error("PUSH_SETTINGS_FAILED", "Unable to open notification settings", null)
            }
            return
        }
        if (call.method != "register") { result.notImplemented(); return }
        if (closed || !foreground) {
            result.error("PUSH_BACKGROUND", "Open the app before registering notifications", null); return
        }
        if (context.packageName != "com.lingmei.kingclub") {
            result.error("PUSH_PACKAGE", "Push requires the registered package", null); return
        }
        if (pending != null) { result.error("PUSH_BUSY", "Registration in progress", null); return }
        val key = call.argument<String>("appKey")
        val secret = call.argument<String>("appSecret")
        if (key.isNullOrBlank() || secret.isNullOrBlank() || key.length > 256 || secret.length > 256) {
            result.error("PUSH_CONFIGURATION", "Missing client push configuration", null); return
        }
        try {
            if (Build.VERSION.SDK_INT >= 26) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                // This ID matches the existing OPPO console legacy channel.
                // Recreating an existing channel cannot override user settings.
                manager.createNotificationChannel(NotificationChannel(
                    "com_lingmei_kingclub", "聊天消息", NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = "好友、群聊消息和通话提醒" })
            }
            HeytapPushManager.init(context.applicationContext, false)
            if (!HeytapPushManager.isSupportPush(context)) {
                result.error("PUSH_UNSUPPORTED", "Device does not support OPPO push", null); return
            }
            pending = result
            fun finish(code: String?, token: String? = null) {
                handler.post {
                    if (pending !== result || closed) return@post
                    timeout?.let(handler::removeCallbacks)
                    timeout = null
                    pending = null
                    if (code == null) result.success(mapOf("provider" to "oppo", "token" to token))
                    else result.error(code, "Push registration did not complete", null)
                }
            }
            timeout = Runnable { finish("PUSH_TIMEOUT") }.also { handler.postDelayed(it, 15000) }
            HeytapPushManager.register(context.applicationContext, key, secret, object : ICallBackResultService {
                override fun onRegister(code: Int, id: String?, pkg: String?, mini: String?) {
                    if (pkg != context.packageName || !mini.isNullOrEmpty()) return
                    if (code == 0 && !id.isNullOrBlank() && id.length <= 4096) finish(null, id)
                    else finish("PUSH_REGISTER_$code")
                }
                override fun onError(code: Int, message: String?, pkg: String?, mini: String?) {
                    if (pkg == context.packageName && mini.isNullOrEmpty()) finish("PUSH_REGISTER_$code")
                }
                override fun onUnRegister(code: Int, pkg: String?, mini: String?) {}
                override fun onSetPushTime(code: Int, time: String?) {}
                override fun onGetPushStatus(code: Int, status: Int) {}
                override fun onGetNotificationStatus(code: Int, status: Int) {}
            })
        } catch (_: Exception) {
            timeout?.let(handler::removeCallbacks)
            timeout = null
            if (pending === result) pending = null
            result.error("PUSH_REGISTER_FAILED", "Push registration failed", null)
        }
    }

    fun close() {
        closed = true
        timeout?.let(handler::removeCallbacks)
        timeout = null
        pending?.error("PUSH_CLOSED", "Registration owner closed", null)
        pending = null
    }
}
