import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_result.dart';

const ref='00000000-0000-4000-8000-000000000001';
Map<String,dynamic> credited()=>{'state':'credited','rechargeRef':ref,'receipt':{
  'version':1,'rechargeRef':ref,'storeRef':'TEST_STORE','userAccount':'TEST_MEMBER',
  'currency':'CNY','accountType':'store_balance','lotRef':'00000000-0000-4000-8000-000000000002',
  'principalCents':'10000','giftCents':'2000','creditedAt':'2026-09-30T00:00:00.000Z',
}};
MemberRechargeResult parse(Object? raw)=>MemberRechargeResult.parse(raw,storeRef:'TEST_STORE',
  rechargeRef:ref,userAccount:'TEST_MEMBER',principalCents:10000,giftCents:2000);
void main(){
  test('only credited produces separate original credit amounts',(){
    final value=parse(credited());
    expect(value.credited,isTrue);expect(value.principalCents,10000);expect(value.giftCents,2000);
    for(final state in ['not_sent','pending','unknown','review_required','credit_pending']){
      final pending=parse({'state':state,'rechargeRef':ref});
      expect(pending.credited,isFalse);expect(pending.principalCents,isNull);expect(pending.giftCents,isNull);
    }
  });
  test('receipt must belong to original store member and both expected amounts',(){
    for(final entry in {'storeRef':'OTHER','userAccount':'OTHER','accountType':'platform_cash',
      'principalCents':'12000','giftCents':'0','creditedAt':'2026-02-30T00:00:00.000Z',
      'lotRef':'invalid','currency':'USD','extra':true}.entries){
      final raw=credited();raw['receipt'][entry.key]=entry.value;
      expect(()=>parse(raw),throwsFormatException);
    }
  });
  test('pending result cannot smuggle a receipt or imply paid success',(){
    expect(()=>parse({...credited(),'state':'credit_pending'}),throwsFormatException);
    expect(()=>parse({'state':'paid','rechargeRef':ref}),throwsFormatException);
  });
}
