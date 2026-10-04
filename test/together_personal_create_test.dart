import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/together_store.dart';
import 'package:kingclub/src/features/club/presentation/together_party_create_page.dart';

class _Stores implements TogetherStoreRepository {
  @override
  Future<List<TogetherStore>> list({required String cityCode}) async => [
    TogetherStore(
      ref: 'store',
      name: 'KINGCLUB湖南工业大学南门测试门店',
      cityCode: cityCode,
      address: '地址',
    ),
  ];
  @override
  Future<List<TogetherTable>> tables({required String storeRef}) async => [
    TogetherTable(
      ref: 'table',
      storeRef: storeRef,
      name: 'V1',
      maximumSeats: 4,
    ),
  ];
}

void main() {
  testWidgets(
    'personal form constrains seats, cancels picker and keeps deposit visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: TogetherPartyCreatePage(
            personal: true,
            cityCode: '430200',
            cityName: '株洲市',
            onBack: () {},
            stores: _Stores(),
            loadLibrary: () async => [],
            uploadArtwork: () async => null,
            onReview: (_) async => fail('Incomplete form must not submit'),
          ),
        ),
      );
      expect(find.text('门店官方发起'), findsNothing);
      await tester.tap(find.text('株洲市 · 请选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('KINGCLUB湖南工业大学南门测试门店'));
      await tester.pumpAndSettle();
      final storeButton = find.ancestor(
        of: find.text('KINGCLUB湖南工业大学南门测试门店'),
        matching: find.byType(TextButton),
      );
      expect(tester.getRect(storeButton).right, closeTo(390 - 28, 0.1));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('请选择').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('V1'));
      await tester.pumpAndSettle();
      expect(find.text('4 人'), findsOneWidget);
      final seatsButton = find.ancestor(
        of: find.text('4 人'),
        matching: find.byType(TextButton),
      );
      expect(tester.getRect(seatsButton).right, closeTo(390 - 28, 0.1));
      await tester.tap(find.text('4 人'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoPicker), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('4 人'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('personal-party-form')),
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('personal-party-deposit')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      final error = find.byKey(const ValueKey('personal-party-error'));
      final deposit = find.byKey(const ValueKey('personal-party-deposit'));
      expect(error.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(error).bottom,
        lessThan(tester.getRect(deposit).top),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
