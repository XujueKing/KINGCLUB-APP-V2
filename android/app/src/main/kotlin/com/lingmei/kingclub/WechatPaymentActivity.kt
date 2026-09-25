package com.lingmei.kingclub
import android.app.Activity
import android.content.Intent
import android.os.Bundle
import com.tencent.mm.opensdk.openapi.IWXAPIEventHandler
import com.tencent.mm.opensdk.openapi.WXAPIFactory
import com.tencent.mm.opensdk.modelbase.BaseReq
import com.tencent.mm.opensdk.modelbase.BaseResp

class WechatPaymentActivity : Activity(), IWXAPIEventHandler {
    override fun onCreate(savedInstanceState: Bundle?) { super.onCreate(savedInstanceState); handle(intent) }
    override fun onNewIntent(intent: Intent) { super.onNewIntent(intent); setIntent(intent); handle(intent) }
    private fun handle(intent: Intent) {
        val appId = getSharedPreferences("wechat_payment", 0).getString("appId", null)
        if (appId == null) { finish(); return }
        try { if (!WXAPIFactory.createWXAPI(this, appId, true).handleIntent(intent, this)) finish() }
        catch (_: Exception) { finish() }
    }
    override fun onReq(req: BaseReq) { finish() }
    override fun onResp(resp: BaseResp) { finish() } // Never mark an order paid from SDK result.
}
