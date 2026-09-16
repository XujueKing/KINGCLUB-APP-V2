package com.lingmei.kingclub

import android.Manifest
import androidx.core.content.PermissionChecker
import android.content.Intent
import android.os.Build
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var nearby: NearbyLanDiscovery? = null
    private var export: ChatFileExport? = null
    private var videoUpload: ChatVideoUpload? = null
    private var foreground = false
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kingclub/call-foreground")
            .setMethodCallHandler { call, result ->
                val id = call.argument<String>("id") ?: ""
                if (!Regex("^[a-f0-9-]{36}$").matches(id)) {
                    result.error("CALL_SERVICE_INPUT", "Invalid call lease", null)
                } else if (call.method == "stop") {
                    CallForegroundService.stop(this, id)
                    result.success(null)
                } else if (call.method == "start") {
                    if (!foreground) result.error("CALL_SERVICE_BACKGROUND", "Open the call in foreground", null)
                    else CallForegroundService.start(this, id, call.argument<Boolean>("video") == true,
                        object : MethodChannel.Result {
                            override fun success(value: Any?) {
                                result.success(value)
                                requestCallNotificationPermission()
                            }
                            override fun error(code: String, message: String?, details: Any?) {
                                result.error(code, message, details)
                            }
                            override fun notImplemented() { result.notImplemented() }
                        })
                } else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kingclub/chat-map")
            .setMethodCallHandler { call, result -> ChatMap.handle(this, call, result) }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kingclub/microphone")
            .setMethodCallHandler { call, result ->
                if (call.method == "isRecordingAllowed") {
                    result.success(PermissionChecker.checkSelfPermission(
                        this, Manifest.permission.RECORD_AUDIO
                    ) == PermissionChecker.PERMISSION_GRANTED)
                } else {
                    result.notImplemented()
                }
            }
        val discovery = NearbyLanDiscovery(this)
        nearby = discovery
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kingclub/nearby-lan")
            .setMethodCallHandler(discovery::handle)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "kingclub/nearby-lan-events")
            .setStreamHandler(discovery)
        val video = ChatVideoUpload(this)
        videoUpload = video
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kingclub/chat-video-upload")
            .setMethodCallHandler(video::handle)
        val handler = ChatFileExport(this)
        export = handler
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kingclub/chat-file-export")
            .setMethodCallHandler(handler::handle)
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (export?.onActivityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onStop() {
        nearby?.stop()
        super.onStop()
    }
    private fun requestCallNotificationPermission() {
        // Start capture's foreground service first. Notification permission is
        // optional for FGS and its dialog must not invalidate service startup.
        if (!foreground || Build.VERSION.SDK_INT < 33 ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        val preferences = getSharedPreferences("call-notification-permission", MODE_PRIVATE)
        if (preferences.getBoolean("asked", false)) return
        preferences.edit().putBoolean("asked", true).apply()
        try {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4202)
        } catch (_: Exception) {
            // The ongoing call remains valid even if the optional prompt fails.
        }
    }
    override fun onResume() {
        super.onResume()
        foreground = true
    }
    override fun onPause() {
        foreground = false
        super.onPause()
    }
    override fun onDestroy() {
        CallForegroundService.shutdown(this)
        nearby?.stop()
        videoUpload?.dispose()
        export?.dispose()
        super.onDestroy()
    }
}
