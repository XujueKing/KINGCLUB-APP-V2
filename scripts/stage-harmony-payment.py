"""Apply Harmony-only SDK routing to an isolated app; no backend transactions."""
from pathlib import Path
import sys

repo = Path(__file__).resolve().parent.parent
root = Path(sys.argv[1]).resolve()
if root == repo or repo in root.parents or not root.is_dir():
    raise SystemExit('Use an isolated Harmony application.')
data = root / 'lib/src/features/commerce/data'
config = data / 'harmony_payment_config.dart'
if config.exists():
    raise SystemExit('Already staged; review before overwriting.')
changes = {}
wx = data / 'ios_wechat_payment.dart'
s = wx.read_text(encoding='utf-8')
anchor = "  static const enabled = bool.fromEnvironment('KINGCLUB_IOS_WECHAT_PAYMENT');"
if anchor not in s: raise SystemExit('Review WeChat bridge.')
s = "import 'package:flutter/foundation.dart';\nimport 'harmony_payment_config.dart';\n" + s
s = s.replace(anchor, "  static bool get enabled => defaultTargetPlatform == TargetPlatform.ohos\n      ? HarmonyPaymentConfig.wechatEnabled\n      : const bool.fromEnvironment('KINGCLUB_IOS_WECHAT_PAYMENT');")
s = s.replace("static const appId = 'wxc6428fd9a2133384';", "static String get appId => defaultTargetPlatform == TargetPlatform.ohos\n      ? HarmonyPaymentConfig.wechatAppId : 'wxc6428fd9a2133384';")
s = s.replace('    return registered && await _sdk.isWeChatInstalled;', '''    if (!registered) return false;
    if (defaultTargetPlatform == TargetPlatform.ohos) await _sdk.attemptToResumeMsgFromWx();
    return await _sdk.isWeChatInstalled;''')
s = s.replace('      sign: values[\'sign\']!,', "      sign: values['sign']!,\n      signType: values['signType'],")
s = s.replace('  static Future<bool> pay(Map<String, String> values) =>\n      _sdk.pay(which: parse(values));', '''  static Future<bool> pay(Map<String, String> values) async {
    if (defaultTargetPlatform == TargetPlatform.ohos && !enabled) {
      throw PlatformException(code: 'HARMONY_PAYMENT_NOT_CONFIGURED');
    }
    return _sdk.pay(which: parse(values));
  }''')
changes[wx] = s
ali = data / 'alipay_app_payment.dart'
s = ali.read_text(encoding='utf-8')
s = "import 'package:flutter/foundation.dart';\nimport 'harmony_payment_config.dart';\n" + s
s = s.replace('  static Future<bool> prepare() => _sdk.isAliPayInstalled;', '''  static Future<bool> prepare() async {
    if (defaultTargetPlatform == TargetPlatform.ohos && !HarmonyPaymentConfig.alipayEnabled) return false;
    return _sdk.isAliPayInstalled;
  }''')
s = s.replace("    final order = payment['orderString'];", '''    if (defaultTargetPlatform == TargetPlatform.ohos && !HarmonyPaymentConfig.alipayEnabled) {
      throw PlatformException(code: 'HARMONY_PAYMENT_NOT_CONFIGURED');
    }
    final order = payment['orderString'];''')
changes[ali] = s
pages = ['commerce/presentation/live_order_payment_page.dart', 'club/presentation/together_booking_page.dart', 'club/presentation/monthly_contracts_page.dart']
for name in pages:
    p = root / 'lib/src/features' / name
    s = p.read_text(encoding='utf-8')
    if 'IosWechatPayment' not in s: raise SystemExit('Review payment page: '+name)
    s = s.replace('defaultTargetPlatform == TargetPlatform.iOS', '(defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.ohos)')
    if name.startswith('commerce/'):
        s = "import '../data/harmony_payment_config.dart';\n" + s
        s = s.replace('    if (kIsWeb ||\n', '''    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.ohos &&
        !(_provider == OrderingPaymentProvider.alipay
            ? HarmonyPaymentConfig.alipayEnabled : HarmonyPaymentConfig.wechatEnabled)) {
      return '当前设备支付尚未开通，已有订单可继续查询。';
    }
    if (kIsWeb ||
''', 1)
    if name.endswith('monthly_contracts_page.dart'):
        s = s.replace('defaultTargetPlatform != TargetPlatform.iOS)))', 'defaultTargetPlatform != TargetPlatform.iOS &&\n                  defaultTargetPlatform != TargetPlatform.ohos)))')
    changes[p] = s
module = root / 'ohos/entry/src/main/module.json5'
s = module.read_text(encoding='utf-8')
if 'querySchemes' in s: raise SystemExit('Review existing payment query schemes.')
changes[module] = s.replace('"module": {', '"module": {\n    "querySchemes": ["weixin", "alipays"],', 1)
for p, s in changes.items(): p.write_text(s, encoding='utf-8')
config.write_text((repo / 'harmony/verification/harmony_payment_config.dart.template').read_text(encoding='utf-8'), encoding='utf-8')
print('Payment routes staged. Real payment remains disabled without explicit Harmony configuration.')
