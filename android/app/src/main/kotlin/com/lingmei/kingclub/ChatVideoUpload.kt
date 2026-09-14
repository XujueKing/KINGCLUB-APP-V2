package com.lingmei.kingclub

import android.content.Context
import android.media.MediaMetadataRetriever
import android.media.MediaExtractor
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.*
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt

/** Private, cancellable upload copy; never overwrites the selected source. */
class ChatVideoUpload(private val context: Context) {
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var transformer: Transformer? = null
    private var pending: MethodChannel.Result? = null
    private var activeId: String? = null
    private var generation = 0
    private var temporary: File? = null
    private var disposed = false
    private val timeout = Runnable { cancel() }
    private data class Info(val width: Int, val height: Int, val duration: Long, val audio: Boolean, val hdr: Boolean)

    private fun inspect(file: File): Info {
        val reader = MediaMetadataRetriever()
        try {
            reader.setDataSource(file.absolutePath)
            fun number(key: Int) = reader.extractMetadata(key)?.toLongOrNull() ?: 0
            var w = number(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH).toInt()
            var h = number(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT).toInt()
            val rotation = number(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            if (rotation == 90L || rotation == 270L) { val old = w; w = h; h = old }
            val extractor = MediaExtractor()
            var hdr = false
            try {
                extractor.setDataSource(file.absolutePath)
                for (track in 0 until extractor.trackCount) {
                    val format = extractor.getTrackFormat(track)
                    if (format.getString("mime")?.startsWith("video/") == true) {
                        val transfer = if (format.containsKey("color-transfer")) format.getInteger("color-transfer") else 0
                        val standard = if (format.containsKey("color-standard")) format.getInteger("color-standard") else 0
                        hdr = hdr || transfer == 6 || transfer == 7 || standard == 6
                    }
                }
            } finally { extractor.release() }
            return Info(w, h, number(MediaMetadataRetriever.METADATA_KEY_DURATION),
                reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_AUDIO) == "yes", hdr)
        } finally { reader.release() }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "progress") {
            val task = transformer
            val holder = ProgressHolder()
            val available = call.argument<String>("id") == activeId && task != null &&
                task.getProgress(holder) == Transformer.PROGRESS_STATE_AVAILABLE
            result.success(if (available) holder.progress.coerceIn(0, 100).toString() else null)
            return
        }
        if (call.method == "release") {
            val key = call.argument<String>("key") ?: ""
            if (Regex("^[a-f0-9]{64}$").matches(key)) File(context.cacheDir, "chat-video-upload/$key.mp4").delete()
            result.success(null); return
        }
        if (call.method == "cancel") {
            if (call.argument<String>("id") == activeId) cancel()
            result.success(null); return
        }
        if (call.method != "prepare") { result.notImplemented(); return }
        if (disposed || pending != null) { result.error("VIDEO_BUSY", "Video processing unavailable", null); return }
        val id = call.argument<String>("id") ?: ""
        val key = call.argument<String>("key") ?: ""
        val path = call.argument<String>("path") ?: ""
        if (!Regex("^[a-f0-9-]{36}$").matches(id) || !Regex("^[a-f0-9]{64}$").matches(key)) {
            result.error("VIDEO_INPUT", "Invalid video input", null); return
        }
        val source = File(path).canonicalFile
        val root = File(context.applicationInfo.dataDir).canonicalFile
        if (!source.path.startsWith(root.path + File.separator) || !source.isFile) {
            Log.i("KingclubVideoUpload", "PRIVATE_INPUT_REQUIRED")
            result.error("VIDEO_INPUT", "Expected a private selected file", null); return
        }
        pending = result; activeId = id
        val current = ++generation
        val directory = File(context.cacheDir, "chat-video-upload").apply { mkdirs() }
        val output = File(directory, "$key.mp4")
        val part = File(directory, "$id.part.mp4")
        temporary = part
        main.postDelayed(timeout, 120_000)
        worker.execute {
            try {
                val before = inspect(source)
                val bitrate = source.length() * 8000.0 / max(1, before.duration)
                val valid = before.width > 0 && before.height > 0 && before.duration in 500..120000
                val skip = !valid || before.hdr || source.length() < 4 * 1024 * 1024 ||
                    (bitrate <= 2_200_000 && max(before.width, before.height) <= 1280)
                val cached = !skip && acceptable(output, source, before)
                Log.i("KingclubVideoUpload", "PLAN skip=$skip cached=$cached hdr=${before.hdr} bytes=${source.length()} durationMs=${before.duration}")
                main.post {
                    if (current != generation || disposed) return@post
                    if (skip) finish(null) else if (cached) finish(output) else start(source, output, part, before, current)
                }
            } catch (error: Exception) { Log.i("KingclubVideoUpload", "INSPECT_FAILED ${error.javaClass.simpleName}"); main.post { if (current == generation) finish(null) } }
        }
    }

    private fun acceptable(output: File, source: File, before: Info): Boolean {
        if (!output.isFile || output.length() < 1 || output.length() >= source.length()) return false
        return try {
            val after = inspect(output)
            after.width > 0 && after.height > 0 && max(after.width, after.height) <= 1280 &&
                kotlin.math.abs(after.duration - before.duration) <= 300 && after.audio == before.audio
        } catch (_: Exception) { false }
    }

    private fun start(source: File, output: File, part: File, before: Info, current: Int) {
        try {
            // Android 12+ may raise VBR above the requested rate to enforce its
            // quality floor. Prefer supported CBR for a bounded upload budget.
            val codecs = MediaCodecList(MediaCodecList.REGULAR_CODECS).codecInfos
            fun supportsCbr(codec: MediaCodecInfo, mime: String): Boolean =
                codec.isEncoder && codec.supportedTypes.any { it.equals(mime, true) } &&
                    try { codec.getCapabilitiesForType(mime).encoderCapabilities
                        .isBitrateModeSupported(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR) }
                    catch (_: Exception) { false }
            val avcCbr = codecs.any { supportsCbr(it, MimeTypes.VIDEO_H264) }
            val hardwareHevc = android.os.Build.VERSION.SDK_INT >= 29 && codecs.any {
                it.isHardwareAccelerated && supportsCbr(it, MimeTypes.VIDEO_H265)
            }
            val mime = if (!avcCbr && hardwareHevc) MimeTypes.VIDEO_H265 else MimeTypes.VIDEO_H264
            val cbr = avcCbr || hardwareHevc
            val mode = if (cbr) MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR else MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_VBR
            val maxEdge = 1280.0
            val scale = minOf(1.0, maxEdge / max(before.width, before.height))
            val width = max(2, (before.width * scale / 2).roundToInt() * 2)
            val height = max(2, (before.height * scale / 2).roundToInt() * 2)
            Log.i("KingclubVideoUpload", "ENCODE bitrate=1500000 mode=$mode mime=$mime width=$width height=$height")
            val encoder = DefaultEncoderFactory.Builder(context)
                .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(1_500_000).setBitrateMode(mode).build())
                .setRequestedAudioEncoderSettings(AudioEncoderSettings.Builder().setBitrate(64_000).build()).build()
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(source)))
                .setEffects(Effects(emptyList(), listOf(
                    Presentation.createForWidthAndHeight(width, height, Presentation.LAYOUT_SCALE_TO_FIT),
                    FrameDropEffect.createDefaultFrameDropEffect(30f)))).build()
            val task = Transformer.Builder(context).setVideoMimeType(mime)
                .setAudioMimeType(MimeTypes.AUDIO_AAC).setEncoderFactory(encoder)
                .addListener(object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        if (current != generation) return
                        worker.execute {
                            val okay = acceptable(part, source, before)
                            Log.i("KingclubVideoUpload", "OUTPUT accepted=$okay sourceBytes=${source.length()} outputBytes=${part.length()}")
                            main.post {
                                if (current != generation) { part.delete(); return@post }
                                if (okay && (!output.exists() || output.delete()) && part.renameTo(output)) finish(output)
                                else finish(null)
                            }
                        }
                    }
                    override fun onError(composition: Composition, exportResult: ExportResult, exception: ExportException) {
                        Log.i("KingclubVideoUpload", "ENCODER_FAILED code=${exception.errorCode} cause=${exception.cause?.javaClass?.simpleName}")
                        if (current == generation) finish(null)
                    }
                }).build()
            transformer = task
            task.start(item, part.absolutePath)
        } catch (error: Exception) { Log.i("KingclubVideoUpload", "START_FAILED ${error.javaClass.simpleName}"); finish(null) }
    }

    private fun finish(file: File?) {
        main.removeCallbacks(timeout)
        val old = transformer; transformer = null
        old?.cancel()
        temporary?.delete(); temporary = null
        val result = pending; pending = null; activeId = null
        result?.success(file?.absolutePath)
    }
    private fun cancel() {
        generation++
        finish(null)
    }
    fun dispose() {
        disposed = true
        cancel()
        worker.shutdown()
    }
}
