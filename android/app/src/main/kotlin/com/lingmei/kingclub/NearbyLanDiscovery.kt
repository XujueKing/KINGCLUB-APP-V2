package com.lingmei.kingclub

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayDeque

/** Explicit foreground discovery only. Advertisements are untrusted candidates. */
@Suppress("DEPRECATION")
class NearbyLanDiscovery(context: Context) : EventChannel.StreamHandler {
    private val manager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var current: Run? = null
    private val type = "_kingclub._udp."
    private inner class Run(val id: String, val token: String) {
        var registration: NsdManager.RegistrationListener? = null
        var discovery: NsdManager.DiscoveryListener? = null
        val seen = mutableSetOf<String>()
        val queue = ArrayDeque<NsdServiceInfo>()
        var resolving = false
        val timeout = Runnable { if (current === this) stop("timeout") }
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events; events.success(mapOf("state" to "ready")) }
    override fun onCancel(arguments: Any?) { stop("cancelled"); sink = null }
    private fun emit(run: Run, state: String, extra: Map<String, Any> = emptyMap()) {
        if (current === run) sink?.success(mapOf("id" to run.id, "state" to state) + extra)
    }
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> {
                val id = call.argument<String>("id") ?: ""
                val port = call.argument<Int>("port") ?: 0
                if (!Regex("[a-f0-9]{32}").matches(id) || port !in 1..65535 || sink == null) {
                    result.error("INVALID_DISCOVERY", "Invalid discovery request or missing listener", null); return
                }
                stop("replaced")
                val run = Run(id, id)
                current = run
                try { start(run, port); result.success(null) }
                catch (_: Exception) { stop("failed"); result.error("DISCOVERY_FAILED", "Local discovery could not start", null) }
            }
            "stop" -> { if (call.argument<String>("id") == current?.id) stop("stopped"); result.success(null) }
            else -> result.notImplemented()
        }
    }
    private fun start(run: Run, port: Int) {
        val registration = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(info: NsdServiceInfo) { main.post {
                if (current === run) emit(run, "advertised")
                else try { manager.unregisterService(this) } catch (_: Exception) { }
            } }
            override fun onRegistrationFailed(info: NsdServiceInfo, code: Int) { main.post { if (current === run) stop("registration_failed") } }
            override fun onServiceUnregistered(info: NsdServiceInfo) { }
            override fun onUnregistrationFailed(info: NsdServiceInfo, code: Int) { }
        }
        run.registration = registration
        val info = NsdServiceInfo().apply {
            serviceName = "KINGCLUB-${run.token.take(12)}"
            serviceType = type
            setPort(port)
            setAttribute("v", "1")
            setAttribute("token", run.token)
        }
        manager.registerService(info, NsdManager.PROTOCOL_DNS_SD, registration)
        val discovery = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) { main.post { emit(run, "discovering") } }
            override fun onDiscoveryStopped(serviceType: String) { }
            override fun onStartDiscoveryFailed(serviceType: String, code: Int) { main.post { if (current === run) stop("discovery_failed") } }
            override fun onStopDiscoveryFailed(serviceType: String, code: Int) { }
            override fun onServiceFound(info: NsdServiceInfo) { main.post {
                if (current !== run || info.serviceType.trimEnd('.') != type.trimEnd('.') || run.seen.size >= 32) return@post
                if (run.seen.add(info.serviceName)) { run.queue.add(info); resolveNext(run) }
            } }
            override fun onServiceLost(info: NsdServiceInfo) { main.post {
                if (current !== run) return@post
                run.seen.remove(info.serviceName)
                run.queue.removeAll { it.serviceName == info.serviceName }
                emit(run, "lost", mapOf("name" to info.serviceName))
            } }
        }
        run.discovery = discovery
        manager.discoverServices(type, NsdManager.PROTOCOL_DNS_SD, discovery)
        main.postDelayed(run.timeout, 60000)
    }
    private fun resolveNext(run: Run) {
        if (current !== run || run.resolving || run.queue.isEmpty()) return
        val info = run.queue.removeFirst()
        run.resolving = true
        try { manager.resolveService(info, object : NsdManager.ResolveListener {
            override fun onResolveFailed(serviceInfo: NsdServiceInfo, code: Int) { main.post {
                run.resolving = false
                resolveNext(run)
            } }
            override fun onServiceResolved(resolved: NsdServiceInfo) { main.post {
                run.resolving = false
                if (current !== run) return@post
                val token = resolved.attributes["token"]?.toString(Charsets.UTF_8) ?: ""
                val version = resolved.attributes["v"]?.toString(Charsets.UTF_8)
                val host = resolved.host?.hostAddress
                if (run.seen.contains(info.serviceName) && version == "1" && token != run.token && Regex("[a-f0-9]{32}").matches(token) && host != null && resolved.port in 1..65535) {
                    emit(run, "found", mapOf("name" to info.serviceName, "host" to host, "port" to resolved.port, "token" to token))
                }
                resolveNext(run)
            } }
        }) } catch (_: Exception) { run.resolving = false; main.post { resolveNext(run) } }
    }
    fun stop(reason: String = "background") {
        val run = current ?: return
        emit(run, "stopped", mapOf("reason" to reason))
        current = null
        main.removeCallbacks(run.timeout)
        run.queue.clear(); run.seen.clear()
        run.discovery?.let { try { manager.stopServiceDiscovery(it) } catch (_: Exception) { } }
        run.registration?.let { try { manager.unregisterService(it) } catch (_: Exception) { } }
    }
}
