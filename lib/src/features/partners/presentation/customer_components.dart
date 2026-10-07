import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/formatters/money.dart';

const customerGold = Color(0xffcebea4);

class CustomerTabs extends StatelessWidget {
  const CustomerTabs({super.key, required this.labels, required this.onTap});
  final List<String> labels;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w400,
        fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily,
      );
      // Equal columns for ordinary text; retain readable text in longer locales.
      final scrollable = labels.any((label) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final tooWide =
            painter.width + 24 > constraints.maxWidth / labels.length;
        painter.dispose();
        return tooWide;
      });
      return DefaultTabController(
        length: labels.length,
        child: TabBar(
          isScrollable: scrollable,
          tabAlignment: scrollable ? TabAlignment.center : TabAlignment.fill,
          labelStyle: style,
          unselectedLabelStyle: style,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
          indicatorSize: TabBarIndicatorSize.label,
          indicatorColor: customerGold,
          dividerColor: Colors.white12,
          onTap: onTap,
          tabs: [for (final label in labels) Tab(text: label, height: 60)],
        ),
      );
    },
  );
}

String customerText(BuildContext context, String key) {
  final l = Localizations.localeOf(context);
  final i = l.languageCode == 'en'
      ? 1
      : l.languageCode == 'th'
      ? 3
      : l.scriptCode == 'Hant' || ['TW', 'HK', 'MO'].contains(l.countryCode)
      ? 2
      : 0;
  return customerCopy[key]!.split('|')[i];
}

const customerCopy = {
  'directory': '客户名录|Customer directory|客戶名錄|รายชื่อลูกค้า',
  'detail': '顾客信息管理|Customer information|顧客資訊管理|ข้อมูลลูกค้า',
  'members': '会员|Members|會員|สมาชิก',
  'marketing': '合作者|Collaborators|合作者|ผู้ร่วมงาน',
  'pending': '审核中|Under review|審核中|รอการตรวจสอบ',
  'blacklist': '黑名单|Restricted|黑名單|ถูกจำกัด',
  'all': '全部|All|全部|ทั้งหมด',
  'reserved': '今日预约|Booked today|今日預約|จองวันนี้',
  'arrived': '今日到店|Arrived today|今日到店|มาถึงวันนี้',
  'male': '男|Male|男|ชาย',
  'female': '女|Female|女|หญิง',
  'search': '昵称、会员号或完整手机号|Name, member ID or full phone|暱稱、會員號或完整手機號|ชื่อ รหัสสมาชิก หรือเบอร์โทรเต็ม',
  'searchAction': '搜索|Search|搜尋|ค้นหา',
  'count': '会员总数|Members found|會員總數|จำนวนสมาชิก',
  'empty': '暂无记录|No records|暫無記錄|ไม่มีข้อมูล',
  'failed':
      '暂时无法读取，请重试|Unable to load. Retry|暫時無法讀取，請重試|โหลดไม่ได้ โปรดลองอีกครั้ง',
  'retry': '重试|Retry|重試|ลองอีกครั้ง',
  'more': '加载更多|Load more|載入更多|โหลดเพิ่มเติม',
  'profile': '会员|Member|會員|สมาชิก',
  'ledger': '账目|Transactions|帳目|รายการ',
  'notes': '备注|Notes|備註|หมายเหตุ',
  'memberId': '会员号|Member ID|會員號|รหัสสมาชิก',
  'birthday': '年龄 / 生日|Age / birthday|年齡 / 生日|อายุ / วันเกิด',
  'years': '岁|years|歲|ปี',
  'phone': '电话|Phone|電話|โทรศัพท์',
  'unavailable': '未提供|Not provided|未提供|ไม่ได้ระบุ',
  'copy': '复制|Copy|複製|คัดลอก',
  'copied': '已复制|Copied|已複製|คัดลอกแล้ว',
  'orders': '订单数量|Orders|訂單數量|จำนวนคำสั่งซื้อ',
  'consumption': '累计已付消费|Paid purchases|累計已付消費|ยอดซื้อที่ชำระแล้ว',
  'commission': '累计产生提成|Commission generated|累計產生提成|ค่าคอมมิชชันที่เกิดขึ้น',
  'rank': '等级|Level|等級|ระดับ',
  'platformBalance': '平台余额|Platform balance|平台餘額|ยอดคงเหลือแพลตฟอร์ม',
  'coins': '金币|Coins|金幣|เหรียญ',
  'diamonds': '钻石|Diamonds|鑽石|เพชร',
  'appearance': 'AI魅力值|AI appearance score|AI魅力值|คะแนนภาพลักษณ์ AI',
  'selfie': '实拍|Selfie|實拍|ภาพเซลฟี',
  'portrait': '形象照A|Portrait A|形象照A|ภาพบุคคล A',
  'outfit': '形象照B|Portrait B|形象照B|ภาพบุคคล B',
  'friends': '好友数量|Friends|好友數量|จำนวนเพื่อน',
  'messages': '累计发送消息|Messages sent|累計發送訊息|ข้อความที่ส่ง',
  'team': '直属下级数量|Direct team members|直屬下級數量|สมาชิกทีมโดยตรง',
  'status': '会员状态|Member status|會員狀態|สถานะสมาชิก',
  'active': '正常|Active|正常|ปกติ',
  'suspended': '受限|Restricted|受限|ถูกจำกัด',
  'date': '注册时间|Registered|註冊時間|เวลาสมัคร',
  'referrer': '推荐合作者|Referring collaborator|推薦合作者|ผู้ร่วมงานที่แนะนำ',
  'parent': '上级合作者|Parent collaborator|上級合作者|ผู้ร่วมงานระดับบน',
  'city': '城市|City|城市|เมือง',
  'styles': '着装风格|Style|著裝風格|สไตล์การแต่งตัว',
  'music': '喜欢音乐|Music|喜歡音樂|เพลงที่ชอบ',
  'drinks': '喜欢酒水|Drinks|喜歡酒水|เครื่องดื่มที่ชอบ',
  'events': '喜欢活动|Events|喜歡活動|กิจกรรมที่ชอบ',
  'storeBalances': '门店储值卡|Store cards|門店儲值卡|บัตรเติมเงินร้าน',
  'noteInput': '添加客户备注|Add customer note|新增客戶備註|เพิ่มหมายเหตุลูกค้า',
  'save': '保存备注|Save note|儲存備註|บันทึกหมายเหตุ',
  'savingFailed': '保存未确认，请重试|Save not confirmed. Retry|儲存未確認，請重試|ยังไม่ยืนยันการบันทึก โปรดลองอีกครั้ง',
  'reason': '填写调整原因|Reason for this change|填寫調整原因|เหตุผลในการเปลี่ยนแปลง',
  'restrict': '限制该会员|Restrict member|限制該會員|จำกัดสมาชิก',
  'restore': '恢复该会员|Restore member|恢復該會員|คืนสถานะสมาชิก',
  'cancel': '取消|Cancel|取消|ยกเลิก',
  'confirm': '确认|Confirm|確認|ยืนยัน',
  'changed': '状态已更新|Status updated|狀態已更新|อัปเดตสถานะแล้ว',
  'stateFailed': '操作未确认，请刷新核对|Not confirmed. Refresh to check|操作未確認，請重新整理核對|ยังไม่ยืนยัน โปรดรีเฟรชเพื่อตรวจสอบ',
  'statusRecord': '会员状态调整|Member status change|會員狀態調整|การเปลี่ยนสถานะสมาชิก',
  'month': '账目月份|Month|帳目月份|เดือน',
  'order': '扫码点单付款|Order payment|掃碼點單付款|ชำระคำสั่งซื้อ',
  'order_refund': '点单退款|Order refund|點單退款|คืนเงินคำสั่งซื้อ',
  'party': '活动付款|Party payment|活動付款|ชำระกิจกรรม',
  'party_refund': '活动退款|Party refund|活動退款|คืนเงินกิจกรรม',
  'store_balance': '储值卡流水|Store card movement|儲值卡流水|รายการบัตรเติมเงิน',
  'commission_refund': '提成冲正|Commission reversal|提成沖正|คืนค่าคอมมิชชัน',
  'recordScope': '账目按下单会员归属；储值与平台余额独立核算|Orders are attributed to the ordering member; store cards and platform funds are separate|帳目按下單會員歸屬；儲值與平台餘額獨立核算|รายการเป็นของผู้สั่งซื้อ บัตรร้านและเงินแพลตฟอร์มแยกกัน',
};

String customerDate(Object? value) {
  if (value == null) return '—';
  final raw = value.toString();
  final d = DateTime.tryParse(
    raw.endsWith('Z') ? raw : '${raw.replaceFirst(' ', 'T')}Z',
  )?.toLocal();
  if (d == null) return raw;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}

String customerAmount(Object? cents, [String currency = 'CNY']) =>
    '${currency == 'CNY' ? '¥' : '$currency '}${moneyCents(cents ?? '0')}';

class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({super.key, required this.customer, this.size = 52});
  final Map<String, dynamic> customer;
  final double size;
  @override
  Widget build(BuildContext context) {
    Widget image = const ColoredBox(
      color: Color(0xff302a21),
      child: Icon(Icons.person_outline, color: customerGold),
    );
    final base64 = customer['avatarBase64'];
    if (base64 is String && base64.isNotEmpty) {
      try {
        image = Image.memory(
          base64Decode(base64),
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      } catch (_) {
        /* Retain fallback for unavailable media. */
      }
    }
    return ClipOval(
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

Widget customerName(Map<String, dynamic> item, {double size = 17}) {
  final name = item['name'] ?? item['memberId'] ?? '—', real = item['realName'];
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 5,
    children: [
      Text(
        '$name${real is String && real.isNotEmpty && real != name ? ' ($real)' : ''}',
        style: TextStyle(fontSize: size, color: Colors.white),
      ),
      if (item['gender'] == 1 || item['gender'] == 2)
        Icon(
          item['gender'] == 1 ? Icons.male : Icons.female,
          size: 18,
          color: item['gender'] == 1
              ? const Color(0xff58a5e1)
              : const Color(0xffe59cb5),
        ),
    ],
  );
}

class CustomerPanel extends StatelessWidget {
  const CustomerPanel({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xff202020),
      borderRadius: BorderRadius.circular(16),
    ),
    child: child,
  );
}
