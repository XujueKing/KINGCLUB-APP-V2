package com.lingmei.kingclub

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

object ChatMap {
    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "open") { result.notImplemented(); return }
        try {
            val lat = call.argument<Number>("latitudeE6") ?: throw IllegalArgumentException()
            val lon = call.argument<Number>("longitudeE6") ?: throw IllegalArgumentException()
            require(lat.toDouble() == lat.toLong().toDouble() && lat.toLong() in -90000000L..90000000L)
            require(lon.toDouble() == lon.toLong().toDouble() && lon.toLong() in -180000000L..180000000L)
            val system = call.argument<String>("coordinateSystem")
            require(system == "gcj02" || system == "wgs84")
            val name = call.argument<String>("name") ?: throw IllegalArgumentException()
            require(name.isNotBlank() && name.length <= 100)
            val uri = Uri.Builder().scheme("https").authority("uri.amap.com").path("marker")
                .appendQueryParameter("position", String.format(Locale.ROOT, "%.6f,%.6f", lon.toDouble()/1e6, lat.toDouble()/1e6))
                .appendQueryParameter("name", name)
                .appendQueryParameter("coordinate", if (system == "gcj02") "gaode" else "wgs84")
                .appendQueryParameter("src", "KINGCLUB")
                // Keep the web fallback usable without an installed map app.
                // Native auto-launch redirects some browsers to an APK download.
                .appendQueryParameter("callnative", "0").build()
            activity.startActivity(Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE))
            result.success(true)
        } catch (_: IllegalArgumentException) {
            result.error("INVALID_LOCATION", "Invalid location", null)
        } catch (_: Exception) {
            result.error("MAP_UNAVAILABLE", "No map or browser available", null)
        }
    }
}
