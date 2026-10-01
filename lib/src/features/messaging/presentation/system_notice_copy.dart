import 'package:flutter/material.dart';

String systemNoticeText(BuildContext context, String key) {
  final l = Localizations.localeOf(context);
  final i = l.languageCode == 'en'
      ? 1
      : l.languageCode == 'th'
      ? 3
      : l.scriptCode == 'Hant' || {'TW', 'HK', 'MO'}.contains(l.countryCode)
      ? 2
      : 0;
  return _copy[key]?.split('|')[i] ?? key;
}

const _copy = {
  'yesterday': '昨天|Yesterday|昨天|เมื่อวาน',
  'purchase_paid': '购买付款成功|Purchase paid|購買付款成功|ชำระค่าสินค้าสำเร็จ',
  'refund_completed': '退款成功|Refund completed|退款成功|คืนเงินสำเร็จ',
  'douyin_verified':
      '抖音团购券核销成功|Douyin voucher redeemed|抖音團購券核銷成功|ใช้คูปอง Douyin สำเร็จ',
  'meituan_verified':
      '美团团购券核销成功|Meituan voucher redeemed|美團團購券核銷成功|ใช้คูปอง Meituan สำเร็จ',
  'aa_paid': '拼桌购买成功|Shared table purchase paid|拼桌購買成功|ชำระค่าร่วมโต๊ะสำเร็จ',
  'wine_deposited': '存酒成功|Wine stored|存酒成功|ฝากเครื่องดื่มสำเร็จ',
  'wine_collected': '取酒成功|Wine collected|取酒成功|รับเครื่องดื่มสำเร็จ',
  'recharge_paid': '充值到账成功|Recharge credited|充值到帳成功|เติมเงินเข้าบัญชีสำเร็จ',
  'success': '办理成功|Completed|辦理成功|ดำเนินการสำเร็จ',
  'store': '门店：|Store:|門店：|ร้าน:',
  'table': '卡座：|Table:|卡座：|โต๊ะ:',
  'order': '订单编号：|Order:|訂單編號：|คำสั่งซื้อ:',
  'products': '商品：|Products:|商品：|สินค้า:',
  'receipt': '业务编号：|Receipt:|業務編號：|ใบเสร็จ:',
  'quantity': '存入数量：|Stored quantity:|存入數量：|จำนวนที่ฝาก:',
  'remaining': '剩余数量：|Remaining quantity:|剩餘數量：|จำนวนคงเหลือ:',
  'expires': '有效期：|Expires:|有效期：|วันหมดอายุ:',
  'channel': '支付方式：|Payment:|支付方式：|วิธีชำระเงิน:',
  'account': '退款去向：|Refund account:|退款去向：|บัญชีคืนเงิน:',
  'gift': '赠送金额：|Gift amount:|贈送金額：|ยอดโบนัส:',
  'platform_cash': '平台现金余额|Platform cash balance|平台現金餘額|ยอดเงินแพลตฟอร์ม',
  'store_balance': '本店充值余额|Store recharge balance|本店儲值餘額|ยอดเงินร้าน',
  'title': '系统消息|System messages|系統消息|ข้อความระบบ',
  'read_all': '全部已读|Mark all read|全部已讀|อ่านทั้งหมด',
  'empty': '暂无系统消息|No system messages|暫無系統消息|ยังไม่มีข้อความระบบ',
  'retry':
      '加载失败，点击重试|Could not load. Retry|載入失敗，點擊重試|โหลดไม่สำเร็จ ลองอีกครั้ง',
  'more': '加载更早消息|Load earlier messages|載入較早消息|โหลดข้อความก่อนหน้า',
};
