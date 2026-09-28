import 'package:flutter/services.dart';
import 'package:fluwx/fluwx.dart';

/// SDK responses only request an authoritative order refresh, never confirm payment.
class IosWechatPayment {
  static const enabled = bool.fromEnvironment('KINGCLUB_IOS_WECHAT_PAYMENT');
  static const appId = 'wxc6428fd9a2133384';
  static const universalLink = 'https://www.wuyexin.cn/app/';
  static final Fluwx _sdk = Fluwx();

  static Future<bool> prepare() async {
    if (!enabled) return false;
    final registered = await _sdk.registerApi(
      appId: appId,
      universalLink: universalLink,
      doOnAndroid: false,
    );
    return registered && await _sdk.isWeChatInstalled;
  }

  static FluwxCancelable onReturn(void Function() refresh) =>
      _sdk.addSubscriber((event) {
        if (event is WeChatPaymentResponse) refresh();
      });

  static Payment parse(Map<String, String> values) {
    final timestamp = int.tryParse(values['timeStamp'] ?? '');
    if (values['appId'] != appId ||
        values['packageValue'] != 'Sign=WXPay' ||
        timestamp == null ||
        timestamp <= 0 ||
        timestamp > 0xffffffff ||
        ['partnerId', 'prepayId', 'nonceStr', 'sign'].any(
          (key) =>
              values[key] == null ||
              values[key]!.isEmpty ||
              values[key]!.length > 2048,
        )) {
      throw PlatformException(code: 'WECHAT_PAYMENT_CONFIG_MISMATCH');
    }
    return Payment(
      appId: appId,
      partnerId: values['partnerId']!,
      prepayId: values['prepayId']!,
      packageValue: 'Sign=WXPay',
      nonceStr: values['nonceStr']!,
      timestamp: timestamp,
      sign: values['sign']!,
    );
  }

  static Future<bool> pay(Map<String, String> values) =>
      _sdk.pay(which: parse(values));
}
