package com.lingmei.kingclub

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import android.util.Log
import android.widget.FrameLayout
import com.tencent.tencentmap.mapsdk.maps.*
import com.tencent.tencentmap.mapsdk.maps.model.*
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.roundToInt

class ChatLocationPickerMapFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    private val views = mutableSetOf<ChatLocationPickerMap>()
    override fun create(context: Context, id: Int, args: Any?): PlatformView {
        val view = ChatLocationPickerMap(context, id, messenger, args as? Map<*, *> ?: emptyMap<Any, Any>())
        views.add(view)
        view.onDispose = { views.remove(view) }
        return view
    }
    fun resume() = views.toList().forEach { it.resume() }
    fun pause() = views.toList().forEach { it.pause() }
    fun dispose() = views.toList().forEach { it.dispose() }
}

/** The native side accepts/returns GCJ02 only. Dart owns the WGS boundary. */
private class ChatLocationPickerMap(context: Context, id: Int, messenger: BinaryMessenger,
                                    args: Map<*, *>) : PlatformView {
    private val host = FrameLayout(context)
    private val channel = MethodChannel(messenger, "kingclub/location-picker-map/$id")
    private val density = context.resources.displayMetrics.density
    private var view: MapView? = null
    private var map: TencentMap? = null
    private var selected: LatLng? = null
    private var blue: Marker? = null
    private var destination: Marker? = null
    private val details = args["role"] == "details"
    private var target: LatLng? = null
    private var loaded = false
    private var loadState = "loading"
    private var gesture = false
    private var disposed = false
    private var resumed = false
    var onDispose: (() -> Unit)? = null

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) result.error("disposed", "地图已关闭", null)
            else when (call.method) {
                "status" -> result.success(loadState)
                "target" -> {
                    target?.let { map?.moveCamera(CameraUpdateFactory.newLatLngZoom(it, 17f)) }
                    result.success(target != null)
                }
                "cancel" -> { gesture = false; result.success(null) }
                "center", "locate" -> {
                    val data = call.arguments as? Map<*, *>
                    val lat = (data?.get("latitudeE6") as? Number)?.toDouble()?.div(1e6)
                    val lon = (data?.get("longitudeE6") as? Number)?.toDouble()?.div(1e6)
                    if (data?.get("coordinateSystem") != "gcj02" || lat == null || lon == null ||
                        !lat.isFinite() || !lon.isFinite() || lat !in -90.0..90.0 || lon !in -180.0..180.0) {
                        result.error("coordinate", "地点坐标无效", null)
                    } else if (map == null) result.error("map", "地图尚未加载", null)
                    else {
                        gesture = false
                        val point = LatLng(lat, lon)
                        if (!details) selected = point
                        if (data["userLocation"] == true || call.method == "locate") showBlue(point)
                        map!!.moveCamera(CameraUpdateFactory.newLatLngZoom(point, 17f))
                        host.post { anchor(); if (loaded) status("ready") }
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
        try {
            val key = args["key"] as? String ?: ""
            require(key.isNotBlank() && args["privacyAccepted"] == true)
            TencentMapInitializer.setAgreePrivacy(context.applicationContext, true)
            // The pinned SDK separates consent from starting its component container.
            if (!TencentMapInitializer.getAgreePrivacy()) {
                TencentMapInitializer.start(context.applicationContext)
            }
            val options = TencentMapOptions().setMapKey(key).setForceHttps(true)
                .setOnAuthCallback(object : TencentMap.OnAuthResultCallback {
                    override fun onAuthFail(code: Int, message: String?) {
                        Log.w("KingClubMap", "SDK authentication failed code=$code")
                        status("failed")
                    }
                    override fun onAuthSuccess() {}
                })
            val native = MapView(context, options)
            view = native; map = checkNotNull(native.map) { "Map SDK did not initialize" }
            host.addView(native, FrameLayout.LayoutParams(-1, -1))
            map!!.setMapType(TencentMap.MAP_TYPE_NORMAL)
            map!!.uiSettings.apply {
                setZoomControlsEnabled(false); setMyLocationButtonEnabled(false)
                setLogoPosition(TencentMapOptions.LOGO_POSITION_BOTTOM_RIGHT)
                setTiltGesturesEnabled(false)
            }
            map!!.setOnMapLoadedCallback {
                loaded = true
                anchor()
                if (selected != null || target != null) status("ready")
            }
            map!!.setOnCameraChangeListener(object : TencentMap.OnCameraChangeListener {
                override fun onCameraChange(position: CameraPosition) {
                    if (disposed) return
                    if (!details && position.triggers.contains(CameraPosition.Trigger.GESTURE)) {
                        if (!gesture) { gesture = true; channel.invokeMethod("moving", null) }
                        selected = position.target
                    }
                    anchor()
                }
                override fun onCameraChangeFinished(position: CameraPosition) {
                    if (disposed) return
                    anchor()
                    if (!gesture) return
                    gesture = false; selected = position.target
                    channel.invokeMethod("centerChanged", mapOf(
                        "latitudeE6" to (position.target.latitude * 1e6).roundToInt(),
                        "longitudeE6" to (position.target.longitude * 1e6).roundToInt(),
                        "coordinateSystem" to "gcj02", "name" to "地图选点", "address" to ""))
                }
            })
            val lat = (args["latitudeE6"] as? Number)?.toDouble()?.div(1e6)
            val lon = (args["longitudeE6"] as? Number)?.toDouble()?.div(1e6)
            if (args["coordinateSystem"] == "gcj02" && lat != null && lon != null &&
                lat.isFinite() && lon.isFinite() && lat in -90.0..90.0 && lon in -180.0..180.0) {
                val point = LatLng(lat, lon)
                selected = point
                map!!.moveCamera(CameraUpdateFactory.newLatLngZoom(point, 17f))
                if (details) {
                    target = point
                    showDestination(point)
                }
            }
            host.addOnLayoutChangeListener { _, _, _, _, _, _, _, _, _ -> anchor() }
            native.onStart(); resume()
        } catch (error: Exception) {
            // Exception messages can contain provider credentials; log only type and code locations.
            Log.w("KingClubMap", "SDK initialization failed type=${error.javaClass.simpleName} " +
                error.stackTrace.take(4).joinToString(" ") { "${it.className}.${it.methodName}:${it.lineNumber}" })
            host.post { status("failed") }
        }
    }
    private fun showBlue(point: LatLng) {
        blue?.remove()
        val size = (24 * density).roundToInt().coerceAtLeast(24)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val canvas = Canvas(bitmap)
        paint.color = Color.WHITE; canvas.drawCircle(size / 2f, size / 2f, size * .47f, paint)
        paint.color = Color.rgb(0, 153, 255); canvas.drawCircle(size / 2f, size / 2f, size * .34f, paint)
        blue = map?.addMarker(MarkerOptions(point).icon(BitmapDescriptorFactory.fromBitmap(bitmap))
            .anchor(.5f, .5f).infoWindowEnable(false).contentDescription("本次实际定位点"))
    }
    private fun showDestination(point: LatLng) {
        val width = (40 * density).roundToInt()
        val height = (54 * density).roundToInt()
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.rgb(7, 193, 96)
        canvas.drawRoundRect(width * .45f, height * .30f, width * .55f, height.toFloat(),
            width * .05f, width * .05f, paint)
        canvas.drawCircle(width / 2f, width / 2f, width * .48f, paint)
        paint.color = Color.WHITE
        canvas.drawCircle(width / 2f, width / 2f, width * .22f, paint)
        destination = map?.addMarker(MarkerOptions(point)
            .icon(BitmapDescriptorFactory.fromBitmap(bitmap)).anchor(.5f, 1f).infoWindowEnable(false))
    }
    private fun anchor() {
        if (disposed || host.width <= 0) return
        val point = selected ?: return
        val pixels = map?.projection?.toScreenLocation(point) ?: return
        channel.invokeMethod("selectionAnchor", mapOf("x" to pixels.x / density, "y" to pixels.y / density))
    }
    private fun status(state: String) {
        loadState = state
        host.post { if (!disposed) channel.invokeMethod("status", state) }
    }
    fun resume() { if (!disposed && !resumed) { view?.onResume(); resumed = true } }
    fun pause() { if (!disposed && resumed) { view?.onPause(); resumed = false } }
    override fun getView(): View = host
    override fun dispose() {
        if (disposed) return
        pause(); disposed = true
        channel.setMethodCallHandler(null)
        map?.setOnCameraChangeListener(null)
        blue?.remove(); blue = null
        destination?.remove(); destination = null
        view?.onStop(); view?.onDestroy(); host.removeAllViews()
        map = null; view = null; onDispose?.invoke(); onDispose = null
    }
}
