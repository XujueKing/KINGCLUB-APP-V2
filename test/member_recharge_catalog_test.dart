import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/membership_wallet/data/member_recharge_catalog.dart';

// Synthetic fixtures only, not production recharge offers.
Map<String,dynamic> fixture()=>{
  'version':1,'storeRef':'TEST_STORE','storeName':'TEST ONLY','currency':'CNY',
  'snapshotAt':'2026-09-30T00:00:00.000Z','campaigns':[{
    'campaignRef':'TEST_OFFER','campaignRevision':1,'principalCents':'10000','giftCents':'2000',
    'availableUntil':'2026-10-01T00:00:00.000Z','giftExpiresAt':null,
    'rulesSnapshot':{'version':1,'description':'TEST ONLY terms','deductionOrder':'principal_first',
      'maxGiftBasisPoints':2000,'eligibleProductRefs':['TEST_PRODUCT']},
  }],
};
MemberRechargeCatalog parse(Object? raw)=>MemberRechargeCatalog.parse(raw,storeRef:'TEST_STORE');
void main(){
  test('keeps principal, gift, original rules and immutable collections separate',(){
    final raw=fixture(),catalog=parse(raw),offer=catalog.offers.single;
    expect(offer.principalCents,10000);expect(offer.giftCents,2000);
    expect(offer.maxGiftBasisPoints,2000);expect(offer.giftExpiresAt,isNull);
    (raw['campaigns'][0]['rulesSnapshot']['eligibleProductRefs'] as List).clear();
    expect(offer.eligibleProductRefs,['TEST_PRODUCT']);
    expect(()=>offer.eligibleProductRefs!.clear(),throwsUnsupportedError);
    expect(()=>catalog.offers.clear(),throwsUnsupportedError);
  });
  test('empty server catalog creates no invented offers',(){
    expect(parse({...fixture(),'campaigns':[]}).offers,isEmpty);
  });
  test('rejects wrong store and noncanonical timestamps',(){
    for(final entry in {'storeRef':'OTHER_STORE','currency':'USD','snapshotAt':'2026-02-30T00:00:00.000Z','extra':true}.entries){
      expect(()=>parse({...fixture(),entry.key:entry.value}),throwsFormatException);
    }
  });
  test('rejects invalid money, stale offers and duplicate revisions',(){
    for(final entry in {'principalCents':'0','giftCents':2000,'campaignRevision':1.5,
      'availableUntil':'2026-09-30T00:00:00.000Z','giftExpiresAt':'2026-09-29T00:00:00.000Z'}.entries){
      final raw=fixture();raw['campaigns'][0][entry.key]=entry.value;
      expect(()=>parse(raw),throwsFormatException);
    }
    final raw=fixture();(raw['campaigns'] as List).add(raw['campaigns'][0]);
    expect(()=>parse(raw),throwsFormatException);
  });
  test('rejects ambiguous rule display and duplicated product scopes',(){
    for(final entry in {'description':'TEST\u202e','maxGiftBasisPoints':10001,
      'eligibleProductRefs':['TEST_PRODUCT','TEST_PRODUCT']}.entries){
      final raw=fixture();raw['campaigns'][0]['rulesSnapshot'][entry.key]=entry.value;
      expect(()=>parse(raw),throwsFormatException);
    }
  });
}
