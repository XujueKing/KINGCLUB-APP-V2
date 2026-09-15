package com.lingmei.kingclub

import android.Manifest
import androidx.core.content.PermissionChecker
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var nearby: NearbyLanDiscovery? = null
    private var export: ChatFileExport? = null
    private var videoUpload: ChatVideoUpload? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
    override fun onDestroy() {
        nearby?.stop()
        videoUpload?.dispose()
        export?.dispose()
        super.onDestroy()
    }
}
