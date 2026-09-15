package com.lingmei.kingclub

import android.app.Activity
import android.content.Intent
import android.content.ClipData
import android.net.Uri
import android.provider.DocumentsContract
import android.webkit.MimeTypeMap
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/** Only documents freshly returned by this activity's system picker are writable. */
class ChatFileExport(private val activity: Activity) {
    companion object {
        const val REQUEST = 28419
        // Document providers may perform remote I/O. Cleanup must neither block
        // the UI nor queue behind a copy blocked inside a provider write.
        private val cleanupExecutor = Executors.newSingleThreadExecutor()
    }
    private val executor = Executors.newSingleThreadExecutor()
    private var picker: MethodChannel.Result? = null
    private var document: Uri? = null
    private var operationId: String? = null
    private var copying = false
    private var savedDocument: Uri? = null
    private var savedOperationId: String? = null
    private var cancelled = AtomicBoolean(false)

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val requestId = call.argument<String>("operationId")
        if (requestId == null || !Regex("[0-9a-fA-F-]{36}").matches(requestId)) {
            result.error("INVALID", "Invalid export operation", null); return
        }
        when (call.method) {
            "openSaved" -> {
                val uri = savedDocument
                if (uri == null || savedOperationId != requestId) {
                    result.error("INVALID", "No saved document", null); return
                }
                try {
                    val view = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(uri, activity.contentResolver.getType(uri) ?: "application/octet-stream")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        clipData = ClipData.newRawUri("Saved file", uri)
                    }
                    activity.startActivity(Intent.createChooser(view, "打开文件"))
                    result.success(true)
                } catch (_: Exception) {
                    result.error("UNAVAILABLE", "Unable to open saved file", null)
                }
            }
            "choose" -> {
                if (picker != null || document != null || copying) {
                    result.error("BUSY", "Another export is active", null); return
                }
                val name = call.argument<String>("name")
                if (name.isNullOrBlank() || name.length > 180 || name.any { it == '/' || it == '\\' || it.code < 32 }) {
                    result.error("INVALID", "Invalid file name", null); return
                }
                operationId = requestId
                cancelled = AtomicBoolean(false)
                picker = result
                try {
                    activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = MimeTypeMap.getSingleton().getMimeTypeFromExtension(
                            name.substringAfterLast('.', "").lowercase(java.util.Locale.ROOT)
                        ) ?: "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }, REQUEST)
                } catch (_: Exception) {
                    picker = null
                    operationId = null
                    result.error("UNAVAILABLE", "System file picker unavailable", null)
                }
            }
            "copy" -> {
                if (operationId != requestId) {
                    result.error("INVALID", "Export operation changed", null)
                } else copy(call, result)
            }
            "cancel" -> {
                if (savedOperationId == requestId) {
                    savedDocument = null
                    savedOperationId = null
                }
                if (operationId != requestId) { result.success(null); return }
                cancelled.set(true)
                if (!copying) { document?.let { remove(it) }; document = null }
                if (!copying && picker == null) operationId = null
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(request: Int, code: Int, data: Intent?): Boolean {
        if (request != REQUEST) return false
        val result = picker
        picker = null
        val uri = if (code == Activity.RESULT_OK) data?.data else null
        if (cancelled.get() || result == null) {
            operationId = null
            uri?.let { remove(it) }; result?.success(false); return true
        }
        if (uri == null || uri.scheme != "content") { operationId = null; result.success(false); return true }
        document = uri
        result.success(true)
        return true
    }

    private fun copy(call: MethodCall, result: MethodChannel.Result) {
        val uri = document
        if (uri == null || copying || cancelled.get()) {
            result.error("INVALID", "No active document", null); return
        }
        val source: File
        val size = call.argument<Number>("size")?.toLong() ?: -1
        val expected = call.argument<String>("sha256") ?: ""
        try {
            source = File(call.argument<String>("path") ?: "").canonicalFile
            val parent = source.parentFile ?: throw IllegalArgumentException()
            require(parent.parentFile == activity.cacheDir.canonicalFile)
            require(parent.name.startsWith("kingclub-chat-download-"))
            require(source.name == "content.bin" && source.isFile)
            require(size in 0..268435456 && source.length() == size)
            require(Regex("[0-9a-f]{64}").matches(expected))
        } catch (_: Exception) {
            result.error("INVALID", "Invalid private source file", null); return
        }
        copying = true
        val cancellation = cancelled
        executor.execute {
            var success = false
            try {
                source.inputStream().use { input ->
                    val output = activity.contentResolver.openOutputStream(uri, "wt")
                        ?: throw IllegalStateException("No destination")
                    output.use {
                        ChatFileCopy.copy(input, it, size, expected) { cancellation.get() }
                    }
                }
                success = true
            } catch (_: Exception) { /* Never log private paths or document URIs. */ }
            val copied = success
            activity.runOnUiThread {
                copying = false
                document = null
                operationId = null
                if (!copied || cancellation.get()) {
                    remove(uri)
                    result.error("EXPORT_FAILED", "File export cancelled or failed", null)
                } else {
                    savedDocument = uri
                    savedOperationId = call.argument<String>("operationId")
                    result.success(true)
                }
            }
        }
    }

    private fun remove(uri: Uri) {
        // Capture only the application resolver: a delayed provider must not
        // retain this export controller or its destroyed Activity.
        val resolver = activity.applicationContext.contentResolver
        cleanupExecutor.execute {
            try { DocumentsContract.deleteDocument(resolver, uri) } catch (_: Exception) {}
        }
    }

    fun dispose() {
        savedDocument = null
        savedOperationId = null
        cancelled.set(true)
        picker?.success(false)
        picker = null
        if (!copying) { document?.let { remove(it) }; document = null }
        executor.shutdown()
    }
}
