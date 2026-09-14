package com.lingmei.kingclub

import android.Manifest
import androidx.core.content.PermissionChecker
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
    override fun onDestroy() {
        videoUpload?.dispose()
        export?.dispose()
        super.onDestroy()
    }
}
