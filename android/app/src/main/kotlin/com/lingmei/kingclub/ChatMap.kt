package com.lingmei.kingclub

import android.app.Activity
import android.content.Intent
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
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
            val latitude = String.format(Locale.ROOT, "%.6f", lat.toDouble()/1e6)
            val longitude = String.format(Locale.ROOT, "%.6f", lon.toDouble()/1e6)
            val point = "$latitude,$longitude"
            val geo = Intent(Intent.ACTION_VIEW,
                Uri.parse("geo:$point?q=${Uri.encode("$point($name)")}"))
            val manager = activity.packageManager
            val packages = manager.queryIntentActivities(geo, PackageManager.MATCH_DEFAULT_ONLY)
                .map { it.activityInfo.packageName }.toMutableSet()
            packages.addAll(listOf("com.autonavi.minimap", "com.baidu.BaiduMap"))
            val native = packages.mapNotNull { pkg ->
                val mapUri = when (pkg) {
                    "com.autonavi.minimap" -> Uri.Builder().scheme("androidamap").authority("viewMap")
                        .appendQueryParameter("sourceApplication", "KINGCLUB")
                        .appendQueryParameter("poiname", name)
                        .appendQueryParameter("lat", latitude).appendQueryParameter("lon", longitude)
                        .appendQueryParameter("dev", if (system == "wgs84") "1" else "0").build()
                    "com.baidu.BaiduMap" -> Uri.Builder().scheme("baidumap").authority("map").path("marker")
                        .appendQueryParameter("location", point).appendQueryParameter("title", name)
                        .appendQueryParameter("coord_type", system)
                        .appendQueryParameter("src", "andr.lingmei.kingclub").build()
                    // The standard geo protocol specifies WGS84. Never relabel GCJ02.
                    else -> if (system == "wgs84") geo.data else null
                }
                mapUri?.let { Intent(Intent.ACTION_VIEW, it).setPackage(pkg) }
                    ?.takeIf { manager.resolveActivity(it, PackageManager.MATCH_DEFAULT_ONLY) != null }
            }
            val preferred = manager.resolveActivity(geo, PackageManager.MATCH_DEFAULT_ONLY)
                ?.activityInfo?.packageName
            val chosen = native.firstOrNull { it.`package` == preferred }
                ?: native.singleOrNull()
            if (native.isNotEmpty()) {
                val intent = chosen ?: Intent.createChooser(native.first(), "使用地图打开")
                    .putExtra(Intent.EXTRA_INITIAL_INTENTS, native.drop(1).toTypedArray())
                try {
                    activity.startActivity(intent)
                    result.success(true)
                    return
                } catch (_: ActivityNotFoundException) {
                    // An app may have been removed after resolving the intent.
                }
            }
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
