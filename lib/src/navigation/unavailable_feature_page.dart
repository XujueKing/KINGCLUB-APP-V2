import 'package:flutter/material.dart';

import '../core/design_system/king_components.dart';
import 'live_feature_gate.dart';

/// A capability boundary, never an empty real-data result or a success receipt.
class UnavailableFeaturePage extends StatelessWidget {
  const UnavailableFeaturePage({
    super.key,
    required this.feature,
    required this.onBack,
  });

  final UnavailableLiveFeature feature;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final language = locale.languageCode == 'en'
        ? 2
        : locale.languageCode == 'th'
        ? 3
        : locale.scriptCode == 'Hant' ||
              locale.countryCode == 'TW' ||
              locale.countryCode == 'HK'
        ? 1
        : 0;
    final title = const {
      UnavailableLiveFeature.paymentSecurity: [
        '支付安全',
        '支付安全',
        'Payment security',
        'ความปลอดภัยการชำระเงิน',
      ],
      UnavailableLiveFeature.accountDeletion: [
        '永久注销账号',
        '永久註銷帳號',
        'Delete account',
        'ลบบัญชี',
      ],
      UnavailableLiveFeature.orders: [
        '我的订单',
        '我的訂單',
        'My orders',
        'คำสั่งซื้อของฉัน',
      ],
      UnavailableLiveFeature.assets: [
        '资产流水',
        '資產流水',
        'Asset history',
        'ประวัติสินทรัพย์',
      ],
      UnavailableLiveFeature.reservation: [
        '我的预约',
        '我的預約',
        'My reservations',
        'การจองของฉัน',
      ],
      UnavailableLiveFeature.party: [
        'VIP 组局',
        'VIP 組局',
        'VIP parties',
        'ปาร์ตี้ VIP',
      ],
      UnavailableLiveFeature.admission: [
        '入场凭证',
        '入場憑證',
        'Admission pass',
        'บัตรเข้างาน',
      ],
      UnavailableLiveFeature.ordering: [
        '扫码点单',
        '掃碼點單',
        'Scan to order',
        'สแกนเพื่อสั่งซื้อ',
      ],
    }[feature]![language];
    final message = const [
      '此功能的真实服务暂未开放。\n本页不会执行操作，也不会展示演示记录作为你的真实数据。',
      '此功能的真實服務暫未開放。\n本頁不會執行操作，也不會展示示範記錄作為你的真實資料。',
      'This service is not available yet.\nNo action will be performed and no sample records will be shown as your real data.',
      'บริการนี้ยังไม่เปิดใช้งาน\nหน้านี้จะไม่ดำเนินการหรือแสดงข้อมูลตัวอย่างเป็นข้อมูลจริงของคุณ',
    ][language];
    return Scaffold(
      key: ValueKey('unavailable-live-${feature.name}'),
      appBar: kingAppBar(
        context: context,
        title: Text(title),
        leading: KingBackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onBack,
                  child: Text(const ['返回', '返回', 'Back', 'กลับ'][language]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
