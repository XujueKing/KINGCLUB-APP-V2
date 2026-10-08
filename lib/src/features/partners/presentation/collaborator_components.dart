import 'package:flutter/material.dart';

import 'customer_components.dart';

String collaboratorLevel(Map<String, dynamic> partner) {
  final level = partner['partnerLevel'];
  return level is num && level >= 1 && level <= 15 ? 'L${level.toInt()}' : '—';
}

String collaboratorText(BuildContext context, String key) {
  final locale = Localizations.localeOf(context);
  final index = locale.languageCode == 'en'
      ? 1
      : locale.languageCode == 'th'
      ? 3
      : locale.scriptCode == 'Hant' ||
            ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? 2
      : 0;
  return collaboratorCopy[key]!.split('|')[index];
}

Widget collaboratorName(
  BuildContext context,
  Map<String, dynamic> partner, {
  double size = 17,
}) => Wrap(
  spacing: 8,
  runSpacing: 6,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    customerName(partner, size: size),
    CollaboratorBadge(
      role: partner['partnerRole'] as String? ?? 'collaborator',
    ),
  ],
);

class CollaboratorBadge extends StatelessWidget {
  const CollaboratorBadge({super.key, required this.role});
  final String role;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: customerGold.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      collaboratorText(
        context,
        collaboratorCopy.containsKey(role) ? role : 'collaborator',
      ),
      style: const TextStyle(color: customerGold, fontSize: 12, height: 1.3),
    ),
  );
}

Widget collaboratorDirectoryRow(
  BuildContext context,
  Map<String, dynamic> item,
) => Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    CustomerAvatar(customer: item),
    const SizedBox(width: 12),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: collaboratorName(context, item)),
              const SizedBox(width: 8),
              Text(
                collaboratorLevel(item),
                style: const TextStyle(color: customerGold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item['phone'] as String? ?? '—',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            customerDate(item['date']),
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    ),
  ],
);

const collaboratorCopy = {
  'assignment': '身份与负责区域|Identity and region|身份與負責區域|สถานะและพื้นที่',
  'assign': '设置身份与区域|Assign identity and region|設定身份與區域|กำหนดสถานะและพื้นที่',
  'identity': '合作身份|Collaborator identity|合作身份|สถานะผู้ร่วมงาน',
  'chooseProvince': '选择省份|Choose province|選擇省份|เลือกจังหวัด',
  'chooseRegion': '选择负责城市|Choose coverage city|選擇負責城市|เลือกเมืองที่รับผิดชอบ',
  'assignmentReason': '填写调整原因|Reason for assignment|填寫調整原因|เหตุผลในการกำหนด',
  'assignmentHistory':
      '身份调整记录|Assignment history|身份調整記錄|ประวัติการเปลี่ยนสถานะ',
  'assignmentScope': '身份与区域不自动授予管理权限，不改变收益等级和历史提成。|Identity and region do not grant permissions or change earnings grades or historical commissions.|身份與區域不自動授予管理權限，不改變收益等級和歷史提成。|สถานะและพื้นที่ไม่ให้สิทธิ์จัดการหรือเปลี่ยนระดับรายได้และค่าคอมมิชชันย้อนหลัง',
  'saveAssignment': '保存设置|Save assignment|儲存設定|บันทึก',
  'detail': '合作者信息管理|Collaborator information|合作者資訊管理|ข้อมูลผู้ร่วมงาน',
  'superadmin': '超级管理员|Super administrator|超級管理員|ผู้ดูแลระบบสูงสุด',
  'provincial': '省级合作者|Provincial collaborator|省級合作者|ผู้ร่วมงานระดับจังหวัด',
  'regional': '区域合作者|Regional collaborator|區域合作者|ผู้ร่วมงานระดับพื้นที่',
  'collaborator': '合作者|Collaborator|合作者|ผู้ร่วมงาน',
  'level': '收益等级|Earnings level|收益等級|ระดับรายได้',
  'city': '合作城市|Registered city|合作城市|เมืองที่ลงทะเบียน',
  'coverage': '负责区域|Assigned region|負責區域|พื้นที่รับผิดชอบ',
  'unassigned': '未分配|Unassigned|未分配|ยังไม่ได้กำหนด',
  'parent': '上级合作者|Parent collaborator|上級合作者|ผู้ร่วมงานต้นสังกัด',
  'direct': '直接向平台申请|Applied directly|直接向平台申請|สมัครโดยตรง',
  'joined': '合作时间|Collaborating since|合作時間|เริ่มร่วมงาน',
  'active': '合作正常|Active|合作正常|ปกติ',
  'suspended': '合作受限|Restricted|合作受限|ถูกจำกัด',
  'not_enrolled': '尚未登记合作|Not enrolled|尚未登記合作|ยังไม่ได้ลงทะเบียน',
  'cumulativeCents': '累计收益|Total net earnings|累計收益|รายได้สุทธิสะสม',
  'monthlyCents': '本月收益|This month|本月收益|รายได้เดือนนี้',
  'availableCents': '可提现|Withdrawable|可提現|ถอนได้',
  'pendingCents': '待结算|Pending settlement|待結算|รอชำระ',
  'frozenCents': '提现处理中|Payouts in progress|提現處理中|กำลังดำเนินการถอน',
  'paidCents': '累计已提现|Paid withdrawals|累計已提現|ถอนแล้วสะสม',
  'transferredCents': '已转平台余额|Transferred to wallet|已轉平台餘額|โอนไปกระเป๋าแล้ว',
  'commissionCents': '消费提成|Consumption commissions|消費提成|ค่าคอมมิชชันการซื้อ',
  'rewardCents': '任务奖励|Task rewards|任務獎勵|รางวัลภารกิจ',
  'ledgerScope': '收益按独立分佣账本统计，已扣除退款冲正；入账满7天结算。|Independent commission ledger, net of reversals. Entries settle after 7 days.|收益按獨立分佣帳本統計，已扣除退款沖正；入帳滿7天結算。|บัญชีค่าคอมมิชชันแยกต่างหาก หักยอดคืนแล้ว ชำระหลังบันทึก 7 วัน',
  'work': '工作情况|Work overview|工作情況|ภาพรวมการทำงาน',
  'teamCount': '直属下级|Direct team|直屬下級|ทีมโดยตรง',
  'memberCount': '绑定会员|Bound members|綁定會員|สมาชิกที่เชื่อมโยง',
  'taskCount': '参与任务|Tasks joined|參與任務|ภารกิจที่เข้าร่วม',
  'completedCount': '验收通过|Accepted claims|驗收通過|รายการที่อนุมัติ',
  'ongoingCount': '进行中|In progress|進行中|กำลังดำเนินการ',
  'reviewCount': '待验收|Awaiting acceptance|待驗收|รอตรวจรับ',
  'rejectedCount': '未通过|Rejected claims|未通過|รายการที่ไม่ผ่าน',
  'partyCount': '发起派对|Parties hosted|發起派對|งานที่จัด',
  'team': '直属团队|Direct team|直屬團隊|ทีมโดยตรง',
  'members': '绑定会员|Bound members|綁定會員|สมาชิกที่เชื่อมโยง',
  'tasks': '任务记录|Task records|任務記錄|ประวัติภารกิจ',
  'commissions': '提成清单|Earnings ledger|提成清單|รายการค่าคอมมิชชัน',
  'withdrawals': '提现清单|Withdrawal records|提現清單|รายการถอน',
  'introduction': '经验介绍|Experience|經驗介紹|ประสบการณ์',
  'organizer': '带局提成|Hosting commission|帶局提成|ค่าคอมมิชชันการจัดงาน',
  'referrer': '绑定会员提成|Referral commission|綁定會員提成|ค่าคอมมิชชันแนะนำ',
  'task': '任务奖励|Task reward|任務獎勵|รางวัลภารกิจ',
  'claimed': '进行中|In progress|進行中|กำลังดำเนินการ',
  'submitted': '待审核|Under review|待審核|รอตรวจสอบ',
  'approved': '已通过|Approved|已通過|อนุมัติแล้ว',
  'rejected': '已拒绝|Rejected|已拒絕|ปฏิเสธแล้ว',
  'cancelled': '已取消|Cancelled|已取消|ยกเลิกแล้ว',
  'paid': '已打款|Paid|已打款|โอนแล้ว',
  'pending': '待结算|Pending settlement|待結算|รอชำระ',
  'available': '已结算|Settled|已結算|ชำระแล้ว',
  'reversed': '已冲正|Reversed|已沖正|คืนยอดแล้ว',
  'availableAt': '结算时间|Settlement date|結算時間|วันชำระ',
  'paidAt': '打款时间|Payout date|打款時間|วันโอน',
  'proofRef': '付款凭证|Payment reference|付款憑證|หลักฐานการโอน',
  'bank': '银行卡|Bank card|銀行卡|บัตรธนาคาร',
  'wechat': '微信|WeChat|微信|WeChat',
};
