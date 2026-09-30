import 'package:flutter/widgets.dart';

String memberBalanceText(BuildContext context, String key) {
  final locale = Localizations.localeOf(context);
  final index = locale.languageCode == 'en'
      ? 1
      : locale.languageCode == 'th'
      ? 3
      : locale.scriptCode == 'Hant' ||
            ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? 2
      : 0;
  return _copy[key]!.split('|')[index];
}

const _copy = {
  'recharge_principal_first': '先扣本金，再按规则使用赠送|Principal first, then eligible gifts|先扣本金，再按規則使用贈送|หักเงินต้นก่อน แล้วใช้ของแถมตามเงื่อนไข',
  'recharge_gift_first': '先按规则扣赠送，再扣本金|Eligible gifts first, then principal|先按規則扣贈送，再扣本金|ใช้ของแถมตามเงื่อนไขก่อน แล้วหักเงินต้น',
  'rechargeGiftCap': '赠送抵扣比例上限|Maximum gift deduction ratio|贈送抵扣比例上限|สัดส่วนสูงสุดที่ใช้ของแถมหักได้',
  'rechargeProducts': '赠送适用商品编号|Gift-eligible product references|贈送適用商品編號|รหัสสินค้าที่ใช้ของแถมได้',
  'rechargeAllProducts': '全部商品（仍受其他规则限制）|All products, subject to other rules|全部商品（仍受其他規則限制）|สินค้าทั้งหมด ภายใต้เงื่อนไขอื่น',
  'rechargeNoProducts': '无适用商品|No eligible products|無適用商品|ไม่มีสินค้าที่ใช้ได้',
  'rechargeOfferUntil': '活动截止时间|Offer ends|活動截止時間|รายการสิ้นสุด',
  'rechargeTitle': '本店充值|Store recharge|本店儲值|เติมเงินกับร้าน',
  'rechargeNotice': '本店本金与赠送分开记账，不转为平台现金。|Store principal and gifts stay separate from platform cash.|本店本金與贈送分開記帳，不轉為平台現金。|เงินต้นและของแถมร้านแยกจากเงินสดแพลตฟอร์ม',
  'rechargeFailed': '暂未完成，请恢复原请求核对，勿重复创建。|Not completed. Recover the original request; do not create duplicates.|暫未完成，請恢復原請求核對，勿重複建立。|ยังไม่เสร็จ โปรดตรวจสอบคำขอเดิม อย่าสร้างซ้ำ',
  'rechargeEmpty': '本店暂无可用充值活动|No available recharge offers|本店暫無可用儲值活動|ยังไม่มีรายการเติมเงินที่ใช้ได้',
  'rechargeNoExpiry': '原规则未设期限|No expiry in original terms|原規則未設期限|เงื่อนไขเดิมไม่กำหนดวันหมดอายุ',
  'rechargeSelected': '已选择|Selected|已選擇|เลือกแล้ว',
  'rechargeSelect': '选择此活动|Select offer|選擇此活動|เลือกรายการนี้',
  'rechargeWechat': '微信|WeChat Pay|微信|WeChat Pay',
  'rechargeAlipay': '支付宝|Alipay|支付寶|Alipay',
  'rechargeConsent': '我确认门店、本金、赠送及活动规则|I confirm the store, principal, gift and terms|我確認門店、本金、贈送及活動規則|ฉันยืนยันร้าน เงินต้น ของแถม และเงื่อนไข',
  'rechargeCreate': '生成收银交接单（不扣款）|Create cashier handoff (no debit)|產生收銀交接單（不扣款）|สร้างรายการให้แคชเชียร์ (ยังไม่หักเงิน)',
  'rechargeRecover': '恢复并查询原充值单|Recover and query original|恢復並查詢原儲值單|กู้คืนและตรวจสอบรายการเดิม',
  'rechargeHandoff': '交给本店收银员核对；此码仅定位原单，不授权付款。|Show to the store cashier. This locates an order, not payment authorization.|交給本店收銀員核對；此碼僅定位原單，不授權付款。|ให้แคชเชียร์ร้านตรวจสอบ รหัสนี้ระบุรายการ ไม่ใช่การอนุญาตชำระเงิน',
  'recharge_not_sent':
      '尚未发起收款|Payment not sent|尚未發起收款|ยังไม่เริ่มเรียกเก็บเงิน',
  'recharge_pending': '收款处理中|Payment pending|收款處理中|กำลังดำเนินการชำระเงิน',
  'recharge_unknown': '结果不明，请查询原单|Unknown result; query original|結果不明，請查詢原單|ยังไม่ทราบผล โปรดตรวจสอบรายการเดิม',
  'recharge_review_required':
      '需要门店核对|Store review required|需要門店核對|ต้องให้ร้านตรวจสอบ',
  'recharge_credit_pending': '已确认付款，余额待到账|Payment confirmed; credit pending|已確認付款，餘額待到帳|ยืนยันชำระแล้ว รอเพิ่มยอด',
  'recharge_credited': '本次充值已到账，返回余额页重新读取|Recharge credited. Return to reload balances.|本次儲值已到帳，返回餘額頁重新讀取|เติมเงินสำเร็จ กลับไปโหลดยอดคงเหลือใหม่',
  'paymentTitle': '会员付款码|Member payment code|會員付款碼|รหัสชำระเงินสมาชิก',
  'storeAccount': '本店充值余额（本金与赠送按规则扣减）|Store balance (principal and gifts follow store rules)|本店儲值餘額（本金與贈送按規則扣減）|ยอดร้าน (หักเงินต้นและของแถมตามเงื่อนไข)',
  'paymentNotice': '仅授权当前门店从所选账户收款，不自动混扣。请核对收银金额，不向他人发送付款码。|Authorize only this store and account; no automatic mixing. Check the cashier amount and do not share this code.|僅授權目前門店從所選帳戶收款，不自動混扣。請核對收銀金額，勿向他人傳送付款碼。|อนุญาตเฉพาะร้านและบัญชีนี้ ไม่หักรวมอัตโนมัติ ตรวจสอบยอดที่แคชเชียร์และอย่าส่งรหัสให้ผู้อื่น',
  'paymentLimit':
      '本次授权最高金额|Maximum authorized amount|本次授權最高金額|วงเงินอนุญาตครั้งนี้',
  'paymentConsent': '我确认门店、账户及最高金额，授权一次付款|I confirm the store, account and limit for one payment|我確認門店、帳戶及最高金額，授權一次付款|ฉันยืนยันร้าน บัญชี และวงเงินสำหรับชำระหนึ่งครั้ง',
  'paymentExpiry': '付款码最长有效 60 秒、仅可使用一次；显示不代表支付成功。|Valid for at most 60 seconds and one payment. Displaying a code is not payment confirmation.|付款碼最長有效 60 秒、僅可使用一次；顯示不代表付款成功。|รหัสใช้ได้ไม่เกิน 60 วินาทีและหนึ่งครั้ง การแสดงรหัสไม่ใช่การยืนยันชำระสำเร็จ',
  'hideCode': '隐藏付款码（已签发授权到期前仍可能有效）|Hide code (issued authorization may remain valid until expiry)|隱藏付款碼（已簽發授權到期前仍可能有效）|ซ่อนรหัส (การอนุญาตอาจยังใช้ได้จนหมดอายุ)',
  'issueCode': '确认并生成付款码|Confirm and generate code|確認並產生付款碼|ยืนยันและสร้างรหัส',
  'issuing': '正在申请…|Requesting…|正在申請…|กำลังขอ…',
  'paymentFailed': '暂时无法签发，请核对后重新确认；未自动发起扣款。|Unable to issue. Check and confirm again; no debit was started automatically.|暫時無法簽發，請核對後重新確認；未自動發起扣款。|ยังออกรหัสไม่ได้ ตรวจสอบและยืนยันใหม่ ไม่มีการเริ่มหักเงินอัตโนมัติ',
  'payStore': '用本店余额付款|Pay with store balance|用本店餘額付款|ชำระด้วยยอดร้าน',
  'payPlatform':
      '用平台现金付款|Pay with platform cash|用平台現金付款|ชำระด้วยเงินสดแพลตฟอร์ม',
  'title': '我的余额|My balances|我的餘額|ยอดคงเหลือของฉัน',
  'total': '资产展示总额|Total displayed assets|資產展示總額|ยอดสินทรัพย์รวมที่แสดง',
  'notice': '含门店赠送金额，仅汇总展示；各账户分开使用，不代表可提现金额。|Includes store gifts for display only. Accounts are separate; this is not a withdrawable balance.|含門店贈送金額，僅彙總展示；各帳戶分開使用，不代表可提現金額。|รวมยอดของแถมจากร้านเพื่อแสดงเท่านั้น บัญชีแยกกันและไม่ใช่ยอดที่ถอนได้',
  'platform': '平台现金余额|Platform cash|平台現金餘額|ยอดเงินสดแพลตฟอร์ม',
  'principal': '本店充值本金|Store recharge principal|本店儲值本金|เงินต้นที่เติมกับร้าน',
  'gift': '未过期赠送|Unexpired gifts|未到期贈送|ยอดของแถมที่ยังไม่หมดอายุ',
  'expired': '过期赠送（不计入总额）|Expired gifts (excluded from total)|過期贈送（不計入總額）|ยอดของแถมหมดอายุ (ไม่รวมในยอดรวม)',
  'restricted': '账户或门店受限，余额仍保留展示|Account or store restricted; balances remain visible|帳戶或門店受限，餘額仍保留展示|บัญชีหรือร้านมีข้อจำกัด ยังคงแสดงยอดเงิน',
  'empty': '暂无本店充值账户|No store recharge accounts|暫無本店儲值帳戶|ยังไม่มีบัญชีเติมเงินกับร้าน',
  'rulesMissing': '该批次未提供规则说明，请联系门店核对|No rule description for this recharge; check with the store|該批次未提供規則說明，請聯絡門店核對|ไม่มีคำอธิบายเงื่อนไขสำหรับรายการนี้ โปรดตรวจสอบกับร้าน',
  'expiry': '赠送有效期|Gift expiry|贈送有效期|วันหมดอายุของแถม',
  'retry': '重新读取|Reload|重新讀取|โหลดใหม่',
  'failed': '暂时无法读取资产，请稍后重试；不会显示模拟余额。|Balances unavailable. Retry later; no simulated balance is shown.|暫時無法讀取資產，請稍後重試；不會顯示模擬餘額。|ยังอ่านยอดเงินไม่ได้ โปรดลองภายหลัง ไม่มีการแสดงยอดจำลอง',
};
