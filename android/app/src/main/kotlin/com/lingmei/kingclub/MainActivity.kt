package com.lingmei.kingclub

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var export: ChatFileExport? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        export?.dispose()
        super.onDestroy()
    }
}
