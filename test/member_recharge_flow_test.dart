import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_flow.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_journal.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_repository.dart';
import 'member_recharge_journal_test.dart' as fixture;
import 'member_recharge_repository_test.dart' as api;
import 'member_recharge_result_test.dart' as receipt;

void main(){
  test('confirmed credited recovery removes its saved request',()async{
    String? saved;
    final journal=MemberRechargeJournal(read:()async=>saved,write:(v)async{saved=v;});
    await journal.save(fixture.request());
    final flow=MemberRechargeFlow(journal:journal,baseUrl:'https://service.invalid',account:()async=>'TEST_MEMBER',
      repository:MemberRechargeRepository(call:(id,params)async=>id=='K260930000510'?api.original():receipt.credited()));
    expect((await flow.recover(fixture.request(),stillCurrent:()=>true)).credited,isTrue);
    expect(await journal.load(baseUrl:'https://service.invalid',userAccount:'TEST_MEMBER'),isEmpty);
  });
  test('creation persists before network and recovery uses same original key',()async{
    String? saved;final calls=<String>[];
    final journal=MemberRechargeJournal(read:()async=>saved,write:(v)async{saved=v;});
    final flow=MemberRechargeFlow(journal:journal,baseUrl:'https://service.invalid',account:()async=>'TEST_MEMBER',
      repository:MemberRechargeRepository(call:(id,params)async{
        expect(saved,isNotNull);calls.add(id);
        if(id=='K260930000510'){expect(params['requestId'],fixture.request().requestId);return api.original();}
        return {'state':'credit_pending','rechargeRef':api.request};
      }));
    await flow.create(fixture.request(),stillCurrent:()=>true);
    final result=await flow.recover(fixture.request(),stillCurrent:()=>true);
    expect(calls,['K260930000510','K260930000510','K260930000511']);expect(result.credited,isFalse);
    expect((await journal.load(baseUrl:'https://service.invalid',userAccount:'TEST_MEMBER')).length,1);
  });
  test('failed persistence blocks network entirely',()async{
    var calls=0;
    final flow=MemberRechargeFlow(baseUrl:'https://service.invalid',account:()async=>'TEST_MEMBER',
      journal:MemberRechargeJournal(read:()async=>null,write:(v)async{}),
      repository:MemberRechargeRepository(call:(id,params)async{calls++;return api.original();}));
    await expectLater(flow.create(fixture.request(),stillCurrent:()=>true),throwsStateError);expect(calls,0);
  });
  test('context invalidated during save retains original without creating',()async{
    String? saved;var current=true,calls=0;
    final flow=MemberRechargeFlow(baseUrl:'https://service.invalid',account:()async=>'TEST_MEMBER',
      journal:MemberRechargeJournal(read:()async=>saved,write:(v)async{saved=v;current=false;}),
      repository:MemberRechargeRepository(call:(id,params)async{calls++;return api.original();}));
    await expectLater(flow.create(fixture.request(),stillCurrent:()=>current),throwsStateError);
    expect(calls,0);expect(saved,isNotNull);
  });
  test('different member cannot replay saved request',()async{
    var calls=0;
    final flow=MemberRechargeFlow(baseUrl:'https://service.invalid',account:()async=>'OTHER',
      repository:MemberRechargeRepository(call:(id,params)async{calls++;return api.original();}));
    await expectLater(flow.recover(fixture.request(),stillCurrent:()=>true),throwsStateError);expect(calls,0);
  });
}
