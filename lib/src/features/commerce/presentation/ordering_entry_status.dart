import 'package:flutter/material.dart';

/// Safe local copy: never render a server exception or infer reservation state.
class OrderingEntryStatus {
  const OrderingEntryStatus(this.code);
  final String code;

  bool get requiresLogin => const {
    'SESSION_EXPIRED',
    'SESSION_CHANGED',
    'UNAUTHORIZED',
  }.contains(code);
  bool get canRefresh =>
      !requiresLogin &&
      !const {
        'ORDERING_SERVICE_UNAVAILABLE',
        'ORDERING_CODE_INVALID',
        'ORDERING_STORE_MISMATCH',
        'ORDERING_TABLE_UNAVAILABLE',
        'MEMBERSHIP_REQUIRED',
      }.contains(code);

  static String text(Locale locale, List<String> values) {
    final traditional =
        locale.scriptCode == 'Hant' ||
        const {'TW', 'HK', 'MO'}.contains(locale.countryCode);
    final index = switch (locale.languageCode) {
      'en' => 1,
      'th' => 3,
      'zh' when traditional => 2,
      _ => 0,
    };
    return values[index];
  }

  String message(Locale locale) => text(locale, switch (code) {
    'ORDERING_SERVICE_UNAVAILABLE' => [
      '桌台点单服务尚未接通',
      'Table ordering is not available yet.',
      '桌台點單服務尚未接通',
      'ยังไม่เปิดให้บริการสั่งอาหารที่โต๊ะ',
    ],
    'ORDERING_TABLE_NOT_OPEN' => [
      '请联系员工确认预约或开台，确认后刷新',
      'Ask staff to confirm your reservation or open the table, then refresh.',
      '請聯繫員工確認預約或開台，確認後重新整理',
      'กรุณาให้พนักงานยืนยันการจองหรือเปิดโต๊ะ แล้วรีเฟรช',
    ],
    'ORDERING_TABLE_CLEARING' => [
      '桌台正在清台，请稍候再刷新',
      'This table is being cleared. Please refresh later.',
      '桌台正在清台，請稍候再重新整理',
      'กำลังเคลียร์โต๊ะ กรุณารอสักครู่แล้วรีเฟรช',
    ],
    'ORDERING_STORE_CLOSED' => [
      '门店暂未营业，暂不能点单',
      'The store is closed. Ordering is unavailable.',
      '門店暫未營業，暫不能點單',
      'ร้านยังไม่เปิดให้บริการ จึงยังสั่งอาหารไม่ได้',
    ],
    'ORDERING_STORE_MISMATCH' => [
      '桌卡与门店不匹配，请联系员工核对',
      'The code does not match this store. Please ask staff to check.',
      '桌卡與門店不匹配，請聯繫員工核對',
      'รหัสโต๊ะไม่ตรงกับร้าน กรุณาให้พนักงานตรวจสอบ',
    ],
    'ORDERING_TABLE_UNAVAILABLE' || 'ORDERING_CODE_INVALID' => [
      '桌卡不可用，请联系员工核对',
      'This table code is unavailable. Please ask staff to check.',
      '桌卡不可用，請聯繫員工核對',
      'รหัสโต๊ะนี้ใช้ไม่ได้ กรุณาให้พนักงานตรวจสอบ',
    ],
    'MEMBERSHIP_REQUIRED' => [
      '请先完成会员注册，再扫码点单',
      'Complete membership registration before ordering.',
      '請先完成會員註冊，再掃碼點單',
      'กรุณาสมัครสมาชิกให้เสร็จก่อนสแกนสั่งอาหาร',
    ],
    'SESSION_EXPIRED' || 'SESSION_CHANGED' || 'UNAUTHORIZED' => [
      '登录状态已变更，请重新登录后扫码',
      'Please sign in again and scan the table code.',
      '登入狀態已變更，請重新登入後掃碼',
      'กรุณาเข้าสู่ระบบอีกครั้งแล้วสแกนรหัสโต๊ะ',
    ],
    'ORDERING_CONTEXT_INCOMPLETE' || 'ORDERING_CONTEXT_INVALID' => [
      '桌台资料不完整，请联系员工核对',
      'Table details are incomplete. Please ask staff to check.',
      '桌台資料不完整，請聯繫員工核對',
      'ข้อมูลโต๊ะไม่ครบถ้วน กรุณาให้พนักงานตรวจสอบ',
    ],
    _ => [
      '暂时无法读取桌台信息，请重试',
      'Unable to load table details. Please try again.',
      '暫時無法讀取桌台資訊，請重試',
      'ไม่สามารถโหลดข้อมูลโต๊ะได้ กรุณาลองอีกครั้ง',
    ],
  });
}
