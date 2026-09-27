package com.lingmei.kingclub

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel

/** Owns the background receiver, independently of the Activity's Flutter engine. */
class ChatConnectionService : Service() {
    companion object {
        private const val CHANNEL = "kingclub_connection_v1"
        private const val ID = 4290
        private const val PREFS = "chat-background-receiver"
        private var instance: ChatConnectionService? = null
        private var uiForeground = false
        fun enabled(context: Context) = context.getSharedPreferences(PREFS, MODE_PRIVATE)
            .getBoolean("enabled", true)
        fun foreground(value: Boolean) {
            uiForeground = value
            instance?.control?.invokeMethod("changed", null)
        }
        fun start(context: Context): Boolean {
            if (!enabled(context)) return false
            if (instance != null) return true
            return try {
                val intent = Intent(context, ChatConnectionService::class.java)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
                true
            } catch (error: Exception) {
                android.util.Log.w("KingclubReceiver", "request failed: ${error.javaClass.simpleName}: ${error.message}")
                false
            }
        }
        fun stop(context: Context) {
            context.stopService(Intent(context, ChatConnectionService::class.java))
        }
        fun setEnabled(context: Context, value: Boolean) {
            context.getSharedPreferences(PREFS, MODE_PRIVATE).edit().putBoolean("enabled", value).apply()
            if (!value) stop(context)
        }
        fun handle(context: Context, call: io.flutter.plugin.common.MethodCall,
                   result: MethodChannel.Result, foreground: Boolean) {
            when (call.method) {
                "enabled" -> result.success(enabled(context))
                "running" -> result.success(instance != null)
                "settings" -> {
                    try {
                        context.startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            android.net.Uri.parse("package:${context.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    } catch (_: Exception) { result.success(false) }
                }
                "enable" -> { setEnabled(context, call.argument<Boolean>("value") == true); result.success(null) }
                "start" -> {
                    android.util.Log.d("KingclubReceiver", "start request foreground=$foreground enabled=${enabled(context)}")
                    result.success(foreground && start(context))
                }
                "stop" -> { stop(context); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }
    private var engine: FlutterEngine? = null
    private var control: MethodChannel? = null
    override fun onBind(intent: Intent?): IBinder? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "stop") {
            setEnabled(this, false)
            stopSelf()
            return START_NOT_STICKY
        }
        if (!enabled(this)) { stopSelf(); return START_NOT_STICKY }
        android.util.Log.d("KingclubReceiver", "service started")
        try {
            val manager = getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
                NotificationChannel(CHANNEL, "后台消息接收", NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                })
            val open = PendingIntent.getActivity(this, ID, Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val stop = PendingIntent.getService(this, ID, Intent(this, ChatConnectionService::class.java)
                .setAction("stop"), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val notification = (if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
                else Notification.Builder(this))
                .setSmallIcon(android.R.drawable.stat_notify_chat)
                .setContentTitle("KINGCLUB 后台消息接收")
                .setContentText("保持消息和来电连接，点击返回应用")
                .setContentIntent(open).setOngoing(true).setOnlyAlertOnce(true)
                .setCategory(Notification.CATEGORY_SERVICE).setNumber(0)
                .addAction(Notification.Action.Builder(null, "停止后台接收", stop).build()).build()
            if (Build.VERSION.SDK_INT >= 34) startForeground(ID, notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
            else startForeground(ID, notification)
            instance = this
            if (engine == null) {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(applicationContext)
                loader.ensureInitializationComplete(applicationContext, null)
                val receiver = FlutterEngine(applicationContext)
                engine = receiver
                val local = ChatLocalNotifications(applicationContext)
                MethodChannel(receiver.dartExecutor.binaryMessenger, "kingclub/local-notifications")
                    .setMethodCallHandler { call, result -> local.handle(call, result, uiForeground) }
                control = MethodChannel(receiver.dartExecutor.binaryMessenger, "kingclub/receiver-control").also {
                    it.setMethodCallHandler { call, result ->
                        when (call.method) {
                            "state" -> result.success(!uiForeground && enabled(this))
                            "stop" -> {
                                android.util.Log.d("KingclubReceiver", "receiver has no active session")
                                result.success(null); stopSelf()
                            }
                            else -> result.notImplemented()
                        }
                    }
                }
                receiver.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(), "backgroundMessageReceiver"))
            }
        } catch (error: Exception) {
            android.util.Log.w("KingclubReceiver", "start failed: ${error.javaClass.simpleName}")
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }
    override fun onDestroy() {
        if (instance === this) instance = null
        control?.setMethodCallHandler(null)
        control = null
        engine?.destroy()
        engine = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
