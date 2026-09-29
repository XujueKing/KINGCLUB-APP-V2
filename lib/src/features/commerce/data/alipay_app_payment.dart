import 'package:flutter/services.dart';
import 'package:tobias/tobias.dart';

/// Only the authenticated order API can confirm settlement, never the SDK.
class AlipayAppPayment {
  static final Tobias _sdk = Tobias();

  static Future<bool> prepare() => _sdk.isAliPayInstalled;

  static Future<void> pay(Map<String, String> payment) async {
    final order = payment['orderString'];
    if (payment['provider'] != 'alipay' ||
        order == null ||
        order.trim().isEmpty ||
        order.length > 65536 ||
        order.contains(RegExp(r'[\x00-\x1f]'))) {
      throw PlatformException(code: 'ALIPAY_PAYMENT_INVALID');
    }
    // Pass the signed string unchanged. Do not log it or store SDK results.
    await _sdk.pay(order);
  }
}
