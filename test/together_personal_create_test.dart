import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/together_store.dart';
import 'package:kingclub/src/features/club/data/together_party_draft.dart';
import 'package:kingclub/src/features/club/presentation/together_party_create_page.dart';
import 'package:kingclub/src/features/club/presentation/together_store_picker_page.dart';

class _Stores implements TogetherStoreRepository {
  @override
  Future<List<TogetherStore>> list({required String cityCode}) async => [
    for (final id in ['A', 'B', 'disabled'])
      TogetherStore(
        ref: id,
        name: 'Test store $id',
        cityCode: cityCode,
        address: 'Test address',
        personalPartyEnabled: id != 'disabled',
      ),
    const TogetherStore(
      ref: 'other',
      name: 'Other city',
      cityCode: 'other',
      address: '',
      personalPartyEnabled: true,
    ),
  ];
  @override
  Future<List<TogetherTable>> tables({required String storeRef}) async => [
    TogetherTable(
      ref: '$storeRef-table',
      storeRef: storeRef,
      name: 'V1',
      maximumSeats: 4,
    ),
  ];
}

Future<void> mount(WidgetTester t, {Size size = const Size(390, 844)}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  addTearDown(t.view.resetPadding);
  await t.pumpWidget(
    MaterialApp(
      builder: (_, child) =>
          RepaintBoundary(key: const ValueKey('capture'), child: child!),
      home: TogetherPartyCreatePage(
        personal: true,
        cityCode: '430200',
        cityName: 'Test city',
        onBack: () {},
        stores: _Stores(),
        loadLibrary: () async => [],
        uploadArtwork: () async => null,
        loadPackages: (store) async => [
          TogetherPackage(
            ref: '$store-package',
            storeRef: store,
            name: 'Test package',
            baseTotalMinor: 100000,
          ),
        ],
        onReview: (_) async => fail('Incomplete form must not submit'),
      ),
    ),
  );
}

Future<void> tap(WidgetTester t, String text) async {
  await t.ensureVisible(find.text(text).first);
  await t.tap(find.text(text).first);
  await t.pumpAndSettle();
}

Future<void> enter(WidgetTester t, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await t.ensureVisible(field);
  await t.enterText(field, text);
}

void main() {
  testWidgets('required step one fields and enabled store filtering', (
    t,
  ) async {
    await mount(t);
    await capture(t, 'personal-step-one');
    await tap(t, '下一步');
    expect(find.text('请选择允许组局的商家').hitTestable(), findsOneWidget);
    await tap(t, '选择店铺');
    expect(find.byType(TogetherStorePickerPage), findsOneWidget);
    await capture(t, 'personal-stores');
    expect(find.text('Test store disabled'), findsNothing);
    expect(find.text('Other city'), findsNothing);
    await tap(t, 'Test store A');
    await capture(t, 'personal-step-one');
    await tap(t, '下一步');
    expect(find.text('2 / 5'), findsOneWidget);
    await tap(t, '下一步');
    expect(find.text('请选择组局方案或自定义').hitTestable(), findsOneWidget);
    await tap(t, 'AA组局');
    await capture(t, 'personal-step-one');
    await tap(t, '下一步');
    expect(find.text('请输入活动主题').hitTestable(), findsOneWidget);
    await enter(t, '活动主题', 'Test theme');
    await capture(t, 'personal-step-one');
    await tap(t, '下一步');
    expect(find.text('请输入欢迎语').hitTestable(), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('back preserves text and store change clears table and package', (
    t,
  ) async {
    await mount(t);
    await tap(t, '选择店铺');
    await tap(t, 'Test store A');
    await tap(t, '下一步');
    await tap(t, 'AA组局');
    await enter(t, '活动主题', 'Test theme');
    await enter(t, '欢迎语', 'Test welcome');
    await capture(t, 'personal-step-one');
    await tap(t, '下一步');
    expect(find.text('3 / 5'), findsOneWidget);
    await tap(t, '请选择');
    await tap(t, 'V1');
    final seats = find.ancestor(
      of: find.text('4 人'),
      matching: find.byType(TextButton),
    );
    expect(t.getRect(seats).right, closeTo(362, .1));
    await tap(t, '请选择');
    await tap(t, 'Test package');
    await tap(t, '上一步');
    final theme = find.widgetWithText(TextField, '活动主题');
    await t.ensureVisible(theme);
    expect(t.widget<TextField>(theme).controller!.text, 'Test theme');
    expect(
      t
          .widget<TextField>(find.widgetWithText(TextField, '欢迎语'))
          .controller!
          .text,
      'Test welcome',
    );
    await tap(t, '上一步');
    await tap(t, 'Test store A');
    await tap(t, 'Test store B');
    await capture(t, 'personal-step-one');
    await tap(t, '下一步');
    await tap(t, '下一步');
    expect(find.text('V1'), findsNothing);
    expect(find.text('Test package'), findsNothing);
    expect(find.text('请选择'), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });
  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('first two steps fit without scrolling at $size', (t) async {
      await mount(t, size: size);
      expect(find.widgetWithText(TextField, '活动主题'), findsNothing);
      expect(find.text('AA组局'), findsNothing);
      expect(
        t
            .state<ScrollableState>(find.byType(Scrollable))
            .position
            .maxScrollExtent,
        0,
      );
      expect(find.text('组局玩'), findsNothing);
      expect(find.byTooltip('返回'), findsNothing);
      expect(find.byTooltip('关闭'), findsOneWidget);
      expect(
        t.getTopLeft(find.byKey(const ValueKey('personal-step-title'))),
        const Offset(18, 34),
      );
      expect(t.getCenter(find.text('Test city')).dx, size.width / 2);
      expect(t.getCenter(find.text('选择店铺')).dx, size.width / 2);
      await tap(t, '选择店铺');
      await tap(t, 'Test store A');
      await tap(t, '下一步');
      expect(find.text('2 / 5'), findsOneWidget);
      expect(find.text('Test store A'), findsNothing);
      for (final label in [
        '活动主题',
        '欢迎语',
        'AA组局',
        '男A女免',
        '我请客',
        '自定义',
        '下一步',
      ]) {
        expect(
          (label == '活动主题' || label == '欢迎语'
                  ? find.widgetWithText(TextField, label)
                  : find.text(label))
              .hitTestable(),
          findsOneWidget,
        );
      }
      final scroll = find
          .descendant(
            of: find.byKey(const ValueKey('personal-party-step-1')),
            matching: find.byType(Scrollable),
          )
          .first;
      expect(t.state<ScrollableState>(scroll).position.maxScrollExtent, 0);
      expect(t.takeException(), isNull);
      await enter(t, '欢迎语', 'Welcome');
      t.view.viewInsets = const FakeViewPadding(bottom: 250);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();
      expect(find.text('下一步').hitTestable(), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}

Future<void> capture(WidgetTester t, String name) async {
  if (!const bool.fromEnvironment('SAVE_PERSONAL_PREVIEW')) return;
  await t.pumpAndSettle();
  final boundary = t.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('capture')),
  );
  final image = (await t.runAsync(() => boundary.toImage()))!;
  final bytes = await t.runAsync(
    () => image.toByteData(format: ui.ImageByteFormat.png),
  );
  await t.runAsync(() async {
    final directory = Directory('build/personal-wizard-test-preview');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
  });
  image.dispose();
}
