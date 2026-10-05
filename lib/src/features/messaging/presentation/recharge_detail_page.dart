import 'package:kingclub/src/core/formatters/money.dart';
import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';
import '../data/system_notices_repository.dart';

/// Receipt of this recharge, not the current spendable store balance.
class RechargeDetailPage extends StatelessWidget {
  const RechargeDetailPage({super.key, required this.notice});
  final SystemNotice notice;
  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final index = locale.languageCode == 'en'
        ? 1
        : locale.languageCode == 'th'
        ? 3
        : locale.scriptCode == 'Hant' ||
              ['TW', 'HK', 'MO'].contains(locale.countryCode)
        ? 2
        : 0;
    String t(String text) => text.split('|')[index];
    String money(int cents) => moneyAmount((cents / 100));
    String date(Object? v) =>
        DateTime.tryParse(v?.toString() ?? '')
            ?.toLocal()
            .toString()
            .split('.')
            .first ??
        '—';
    final d = notice.rechargeDetails;
    String summary(String key) =>
        notice.details
            .where((e) => e.$1 == key)
            .map((e) => e.$2 is String ? e.$2 as String : '')
            .firstOrNull ??
        '—';
    Widget row(String name, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              name,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xFFDDDDDD),
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
    Widget card(List<Widget> children) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    final store = d?['storeName']?.toString() ?? summary('store');
    final principal = d?['principalCents'] as int? ?? notice.amountCents ?? 0;
    final gift = d?['giftCents'] as int?;
    final logo = d?['logoUrl']?.toString();
    final logoValid = logo != null && Uri.tryParse(logo)?.scheme == 'https';
    final fallback = const Icon(
      Icons.storefront_outlined,
      size: 40,
      color: Colors.white70,
    );
    final channel = d?['channel'];
    final channelName = channel == 'wechat'
        ? t('微信支付|WeChat Pay|微信支付|WeChat Pay')
        : channel == 'alipay'
        ? t('支付宝支付|Alipay|支付寶支付|Alipay')
        : channel == 'cash'
        ? t('现金|Cash|現金|เงินสด')
        : channel == 'bank_code'
        ? t('银行码收款|Bank QR payment|銀行碼收款|ชำระด้วย QR ธนาคาร')
        : '—';
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: kingAppBar(
        context: context,
        title: Text(t('充值详情|Top-up details|儲值詳情|รายละเอียดการเติมเงิน')),
        centerTitle: true,
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          20,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          children: [
            card([
              Center(
                child: ClipOval(
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: logoValid
                        ? CachedMediaImage(
                            logo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => fallback,
                          )
                        : fallback,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                store,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFDDDDDD),
                  fontSize: 20,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                gift == null ? '—' : '+${money(principal + gift)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  '本店储值卡充值到账|Store credit top-up credited|本店儲值卡儲值到帳|เติมเงินบัตรร้านสำเร็จ',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFF333333)),
              row(
                t('到账状态|Status|到帳狀態|สถานะ'),
                t('已到账|Credited|已到帳|เข้าบัญชีแล้ว'),
              ),
              row(t('门店|Store|門店|ร้าน'), store),
              row(
                t('充值时间|Created|儲值時間|เวลาทำรายการ'),
                d == null ? date(notice.occurredAt) : date(d['createdAt']),
              ),
              row(
                t('到账时间|Credited at|到帳時間|เวลาเข้าบัญชี'),
                date(d?['creditedAt'] ?? notice.occurredAt),
              ),
              row(
                t('办理收银员|Cashier|辦理收銀員|พนักงานรับเงิน'),
                d?['cashierName']?.toString() ??
                    t('未记录|Not recorded|未記錄|ไม่มีข้อมูล'),
              ),
            ]),
            card([
              Text(
                t('充值明细|Top-up breakdown|儲值明細|รายการเติมเงิน'),
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF333333)),
              row(t('实付金额|Amount paid|實付金額|ยอดที่ชำระ'), money(principal)),
              row(t('充值本金|Principal|儲值本金|เงินต้น'), money(principal)),
              row(
                t('赠送金额|Bonus|贈送金額|เงินโบนัส'),
                gift == null ? '—' : money(gift),
              ),
              row(
                t('合计到账|Total credited|合計到帳|ยอดเข้ารวม'),
                gift == null ? '—' : money(principal + gift),
              ),
              row(t('支付方式|Payment method|支付方式|วิธีชำระเงิน'), channelName),
              row(
                t('充值单号|Top-up reference|儲值單號|เลขที่เติมเงิน'),
                d?['rechargeRef']?.toString() ?? summary('receipt'),
              ),
              if (d?['transactionRef'] != null)
                row(
                  t('支付流水号|Transaction ID|支付流水號|เลขธุรกรรม'),
                  d!['transactionRef'].toString(),
                ),
              if (d?['giftExpiresAt'] != null)
                row(
                  t('赠送有效期|Bonus expires|贈送有效期|โบนัสหมดอายุ'),
                  date(d!['giftExpiresAt']),
                ),
              if (d?['rulesDescription'] != null)
                row(
                  t('使用说明|Terms|使用說明|เงื่อนไข'),
                  d!['rulesDescription'].toString(),
                ),
              if (d == null)
                Text(
                  t(
                    '详细记录暂未加载，请返回消息列表重试|Details unavailable. Return to messages and retry.|詳細記錄暫未載入，請返回訊息列表重試|ยังโหลดรายละเอียดไม่ได้ โปรดกลับไปหน้าข้อความแล้วลองอีกครั้ง',
                  ),
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
