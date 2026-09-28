import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/ios_wechat_payment.dart';

void main() {
  final valid = <String, String>{
    'appId': IosWechatPayment.appId,
    'partnerId': 'fixture-merchant',
    'prepayId': 'fixture-prepay',
    'packageValue': 'Sign=WXPay',
    'nonceStr': 'fixture-nonce',
    'timeStamp': '1780000000',
    'sign': 'fixture-sign',
  };
  test('preserves server signed payment parameters', () {
    final payment = IosWechatPayment.parse(valid);
    expect(payment.timestamp, 1780000000);
    expect(payment.partnerId, valid['partnerId']);
    expect(payment.sign, valid['sign']);
  });
  test('rejects wrong app, package and invalid native UInt32 timestamp', () {
    for (final change in [
      {'appId': 'wxMiniProgram'},
      {'packageValue': 'bad'},
      {'timeStamp': '-1'},
      {'timeStamp': '4294967296'},
      {'sign': ''},
    ]) {
      expect(
        () => IosWechatPayment.parse({...valid, ...change}),
        throwsA(isA<PlatformException>()),
      );
    }
  });
}
