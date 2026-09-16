package com.lingmei.kingclub

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel

/** Keeps only an explicitly opened media capture alive; never restarts calls. */
class CallForegroundService : Service() {
    companion object {
        private const val CHANNEL = "kingclub_active_call"
        private const val NOTIFICATION = 4201
        private var lease: String? = null
        private var pending: MethodChannel.Result? = null
        private val handler = Handler(Looper.getMainLooper())
        private var timeout: Runnable? = null

        fun start(context: Context, id: String, video: Boolean, result: MethodChannel.Result) {
            if (lease != null) {
                result.error("CALL_SERVICE_BUSY", "A call already owns capture", null)
                return
            }
            lease = id
            pending = result
            val deadline = Runnable {
                if (lease == id && pending != null) {
                    pending?.error("CALL_SERVICE_TIMEOUT", "Call service did not start", null)
                    pending = null
                    stop(context, id)
                }
            }
            timeout = deadline
            handler.postDelayed(deadline, 8000)
            try {
                val intent = Intent(context, CallForegroundService::class.java)
                    .putExtra("lease", id).putExtra("video", video)
                if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent)
                else context.startService(intent)
            } catch (_: Exception) {
                pending?.error("CALL_SERVICE_START", "Call service unavailable", null)
                pending = null
                stop(context, id)
            }
        }

        fun stop(context: Context, id: String) {
            if (lease != id) return
            lease = null
            timeout?.let { handler.removeCallbacks(it) }
            timeout = null
            pending?.error("CALL_SERVICE_CANCELLED", "Call capture closed", null)
            pending = null
            context.stopService(Intent(context, CallForegroundService::class.java))
        }

        fun shutdown(context: Context) { lease?.let { stop(context, it) } }
    }

    private var ownedLease: String? = null
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val id = intent?.getStringExtra("lease")
        if (id == null || id != lease) {
            stopSelf(startId)
            return START_NOT_STICKY
        }
        ownedLease = id
        try {
            val video = intent.getBooleanExtra("video", false)
            if (Build.VERSION.SDK_INT >= 26) {
                getSystemService(NotificationManager::class.java).createNotificationChannel(
                    NotificationChannel(CHANNEL, "正在通话", NotificationManager.IMPORTANCE_LOW)
                )
            }
            val open = PendingIntent.getActivity(this, 0,
                Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
                else Notification.Builder(this)
            val notification = builder.setSmallIcon(android.R.drawable.stat_sys_phone_call)
                .setContentTitle(if (video) "KINGCLUB 视频通话" else "KINGCLUB 语音通话")
                .setContentText("点击返回通话").setContentIntent(open)
                .setOngoing(true).setCategory(Notification.CATEGORY_CALL)
                .setVisibility(Notification.VISIBILITY_PRIVATE).build()
            if (Build.VERSION.SDK_INT >= 30) {
                startForeground(NOTIFICATION, notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                        (if (video) ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA else 0))
            } else startForeground(NOTIFICATION, notification)
            timeout?.let { handler.removeCallbacks(it) }
            timeout = null
            pending?.success(null)
            pending = null
        } catch (_: Exception) {
            pending?.error("CALL_SERVICE_PERMISSION", "Call service permission unavailable", null)
            pending = null
            stop(this, id)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        if (lease == ownedLease) {
            lease = null
            timeout?.let { handler.removeCallbacks(it) }
            timeout = null
            pending?.error("CALL_SERVICE_STOPPED", "Call service stopped", null)
            pending = null
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}
