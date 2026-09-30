import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_repository.dart';
import 'member_recharge_catalog_test.dart' as catalog;

const request='00000000-0000-4000-8000-000000000001';
Map<String,dynamic> original()=>{'rechargeRef':request,'storeRef':'TEST_STORE','channel':'wechat',
  'principalCents':'10000','giftCents':'2000','paymentStatus':'prepared','creditStatus':'awaiting_payment'};
Future<MemberRechargeOriginal> prepare(MemberRechargeRepository repo)=>repo.prepare(requestId:request,
  storeRef:'TEST_STORE',campaignRef:'TEST_OFFER',campaignRevision:1,channel:'wechat');
void main(){
  test('query sends only original scope and does not create or collect payment',()async{
    var calls=0;
    final repo=MemberRechargeRepository(call:(id,params)async{
      calls++;expect(id,'K260930000511');
      expect(params,{'storeRef':'TEST_STORE','rechargeRef':request});
      return {'state':'credit_pending','rechargeRef':request};
    });
    final saved=MemberRechargeOriginal.parse(original(),storeRef:'TEST_STORE',channel:'wechat');
    final result=await repo.query(saved,userAccount:'TEST_MEMBER');
    expect(calls,1);expect(result.credited,isFalse);expect(result.principalCents,isNull);
  });
  test('prepare sends only original selection and no client amount or identity',()async{
    var calls=0;
    final repo=MemberRechargeRepository(call:(id,params)async{
      calls++;expect(id,'K260930000510');
      expect(params,{'requestId':request,'storeRef':'TEST_STORE','campaignRef':'TEST_OFFER','campaignRevision':1,'channel':'wechat'});
      return original();
    });
    final value=await prepare(repo);
    expect(calls,1);expect(value.principalCents,10000);expect(value.giftCents,2000);
    expect(value.creditStatus,'awaiting_payment');
  });
  test('catalog uses member endpoint and preserves empty versus unavailable',()async{
    final repo=MemberRechargeRepository(call:(id,params)async{
      expect(id,'K260930000512');expect(params,{'storeRef':'TEST_STORE'});
      return catalog.fixture();
    });
    expect((await repo.catalog('TEST_STORE')).offers.single.ref,'TEST_OFFER');
  });
  test('uncertain creation is not retried automatically',()async{
    var calls=0;
    final repo=MemberRechargeRepository(call:(id,params)async{calls++;throw TimeoutException('TEST ONLY');});
    await expectLater(prepare(repo),throwsA(isA<TimeoutException>()));expect(calls,1);
  });
  test('late original result after session change is rejected',()async{
    var generation=0;
    final pending=Completer<Map<String,dynamic>>();
    final repo=MemberRechargeRepository(generation:()=>generation,call:(id,params)=>pending.future);
    final result=prepare(repo);final expectation=expectLater(result,throwsStateError);
    generation++;pending.complete(original());await expectation;
  });
  test('wrong scope, malformed money and inconsistent credit status are rejected',(){
    for(final entry in {'storeRef':'OTHER','channel':'alipay','principalCents':'0','giftCents':2000,
      'creditStatus':'credited','rechargeRef':'not-an-original','extra':true}.entries){
      expect(()=>MemberRechargeOriginal.parse({...original(),entry.key:entry.value},storeRef:'TEST_STORE',channel:'wechat'),throwsFormatException);
    }
  });
}
