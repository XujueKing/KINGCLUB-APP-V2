package com.lingmei.kingclub

import android.app.Activity
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import com.tencent.mm.opensdk.modelpay.PayReq
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

object WechatPayment {
    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pay") { result.notImplemented(); return }
        try {
            fun text(key: String): String = call.argument<String>(key)?.takeIf { it.isNotBlank() && it.length <= 2048 } ?: error("Invalid payment")
            val appId = text("appId")
            require(Regex("^wx[a-zA-Z0-9]+$").matches(appId))
            val api = WXAPIFactory.createWXAPI(activity, appId, true)
            if (!api.isWXAppInstalled) { result.error("WECHAT_NOT_INSTALLED", "请先安装微信", null); return }
            api.registerApp(appId)
            activity.getSharedPreferences("wechat_payment", 0).edit().putString("appId", appId).apply()
            val req = PayReq().apply {
                this.appId = appId; partnerId = text("partnerId"); prepayId = text("prepayId")
                packageValue = text("packageValue"); nonceStr = text("nonceStr")
                timeStamp = text("timeStamp"); sign = text("sign")
            }
            require(req.packageValue == "Sign=WXPay" && req.timeStamp.toLongOrNull() != null)
            result.success(api.sendReq(req)) // Launch only; payment is confirmed by the server.
        } catch (_: Exception) { result.error("WECHAT_LAUNCH_FAILED", "无法调起微信支付", null) }
    }
}
