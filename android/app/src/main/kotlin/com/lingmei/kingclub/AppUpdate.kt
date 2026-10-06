package com.lingmei.kingclub

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class AppUpdate(private val activity: Activity) {
    private val executor = Executors.newSingleThreadExecutor()

    @Suppress("DEPRECATION")
    private fun verify(call: MethodCall): File {
        val file = File(call.argument<String>("path") ?: "").canonicalFile
        val expected = File(activity.cacheDir, "app-updates/update.apk").canonicalFile
        require(file == expected && file.isFile)
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(65536)
            while (true) { val n = input.read(buffer); if (n < 0) break; digest.update(buffer, 0, n) }
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it) }
        require(hash == call.argument<String>("sha256"))
        val pm = activity.packageManager
        val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
        val apk = requireNotNull(pm.getPackageArchiveInfo(file.path, flags))
        val installed = pm.getPackageInfo(activity.packageName, flags)
        val build = if (Build.VERSION.SDK_INT >= 28) apk.longVersionCode else apk.versionCode.toLong()
        val current = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        require(apk.packageName == activity.packageName && build > current && build == call.argument<Number>("build")?.toLong())
        val apkSigners = if (Build.VERSION.SDK_INT >= 28) apk.signingInfo?.apkContentsSigners else apk.signatures
        val localSigners = if (Build.VERSION.SDK_INT >= 28) installed.signingInfo?.apkContentsSigners else installed.signatures
        require(!apkSigners.isNullOrEmpty() && !localSigners.isNullOrEmpty())
        require(apkSigners.toSet() == localSigners.toSet())
        return file
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "verify" && call.method != "install") { result.notImplemented(); return }
        executor.execute {
            try {
                val file = verify(call)
                activity.runOnUiThread {
                    try {
                        if (call.method == "verify") result.success(true)
                        else if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                            activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                Uri.parse("package:${activity.packageName}")))
                            result.success("permission")
                        } else {
                            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", file)
                            activity.startActivity(Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            })
                            result.success("opened")
                        }
                    } catch (_: Exception) { result.error("INSTALL", "Cannot open installer", null) }
                }
            } catch (_: Exception) {
                activity.runOnUiThread { result.error("VERIFY", "Update verification failed", null) }
            }
        }
    }
}
