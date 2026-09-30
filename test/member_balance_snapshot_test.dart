import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_balance_snapshot.dart';

Map<String, dynamic> fixture() => jsonDecode('''{
  "currency":"CNY","snapshotAt":"2026-09-30T00:00:00.000Z",
  "platform":{"accountType":"platform_cash","cashCents":"10000"},
  "summary":{"displayOnly":true,"platformCashCents":"10000",
    "storePrincipalCents":"20000","storeGiftCents":"5000","displayTotalCents":"35000"},
  "stores":[{"storeRef":"test-store","storeName":"Test store","storeStatus":"active",
    "accountStatus":"active","accountType":"store_balance","principalCents":"20000",
    "giftCents":"5000","expiredGiftCents":"1000","displayTotalCents":"25000",
    "lots":[
      {"lotRef":"11111111-1111-4111-8111-111111111111","principalCents":"20000",
        "giftCents":"5000","giftExpired":false,"giftExpiresAt":null,"rulesDescription":"Test rules"},
      {"lotRef":"22222222-2222-4222-8222-222222222222","principalCents":"0",
        "giftCents":"1000","giftExpired":true,"giftExpiresAt":"2026-09-29T00:00:00.000Z",
        "rulesDescription":"Expired test gift"}
    ]}]
}''') as Map<String, dynamic>;

void main() {
  test('display total keeps platform, store principal and gifts separate', () {
    final value = MemberBalanceSnapshot.parse(fixture());
    expect(value.platformCash, BigInt.from(10000));
    expect(value.total, BigInt.from(35000));
    expect(value.stores.single.principal, BigInt.from(20000));
    expect(value.stores.single.gift, BigInt.from(5000));
    expect(value.stores.single.expiredGift, BigInt.from(1000));
    expect(value.stores.single.lots.last.expired, isTrue);
  });
  test('frozen or closed accounts stay visible without becoming spendable', () {
    final raw = fixture();
    raw['stores'][0]['storeStatus'] = 'closed';
    raw['stores'][0]['accountStatus'] = 'frozen';
    expect(MemberBalanceSnapshot.parse(raw).total, BigInt.from(35000));
  });
  test('rejects incomplete or inconsistent financial snapshots', () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (r) => r['platform'].remove('cashCents'),
      (r) => r['summary']['displayOnly'] = false,
      (r) => r['summary']['displayTotalCents'] = '36000',
      (r) => r['stores'][0]['lots'][1]['giftExpired'] = false,
      (r) => r['stores'][0]['lots'][0]['principalCents'] = '19999',
      (r) => r['stores'].add(r['stores'][0]),
      (r) => r['platform']['cashCents'] = 10000,
    ]) {
      final raw = fixture();
      mutate(raw);
      expect(() => MemberBalanceSnapshot.parse(raw), throwsFormatException);
    }
  });
  test('money formatting is exact above JavaScript integer precision', () {
    expect(balanceMoney(balanceCents('9007199254740993')), '90071992547409.93');
    for (final invalid in ['1.1', '-1', '01', '1e3', '', null]) {
      expect(() => balanceCents(invalid), throwsFormatException);
    }
  });
}
