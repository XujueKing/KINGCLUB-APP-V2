import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kingclub/src/features/profile_settings/presentation/edit_profile_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(393, 852),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(body: MyProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pull stretches cover without a top gap and springs back', (
    tester,
  ) async {
    await mount(tester);
    final cover = find.byKey(const ValueKey('my-profile-cover'));
    final initial = tester.getRect(cover);
    final gesture = await tester.startGesture(const Offset(180, 320));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 140));
    await tester.pump();
    final stretched = tester.getRect(cover);
    expect(stretched.height, greaterThan(initial.height + 20));
    expect(stretched.top, closeTo(initial.top, .1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(cover).height, closeTo(initial.height, .1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native slivers pin menu below safe toolbar and reverse without jumping',
    (tester) async {
      await mount(tester);
      final menu = find.byKey(const ValueKey('my-profile-pinned-tabs'));
      final initial = tester.getRect(menu);
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getTopLeft(menu).dy, closeTo(44 + 6 + 60 * 393 / 750, .1));
      await tester.tap(find.byKey(const ValueKey('my-profile-tab-相册')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('my-profile-selected-tab-arrow-相册')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(menu).dy, closeTo(44 + 6 + 60 * 393 / 750, .1));
      await tester.drag(
        find.byKey(const ValueKey('my-profile-pages')),
        const Offset(300, 0),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('my-profile-selected-tab-arrow-动态')),
        findsOneWidget,
      );
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getRect(menu), initial);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'five supplied SVG service entries sit above content and support opens',
    (tester) async {
      await mount(tester);
      final services = find.byKey(const ValueKey('my-profile-services'));
      await tester.ensureVisible(services);
      await tester.pumpAndSettle();
      final rects = ['bump', 'orders', 'reservations', 'creator', 'support']
          .map((id) => tester.getRect(find.byKey(ValueKey('my-profile-$id'))))
          .toList();
      for (final rect in rects) {
        expect(rect.top, rects.first.top);
        expect(rect.width, closeTo(rects.first.width, .01));
      }
      expect(
        tester.getBottomLeft(services).dy,
        lessThanOrEqualTo(
          tester
              .getTopLeft(find.byKey(const ValueKey('my-profile-pinned-tabs')))
              .dy,
        ),
      );
      expect(
        find.descendant(of: services, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.descendant(of: services, matching: find.byType(SvgPicture)),
        findsNWidgets(5),
      );
      await tester.tap(find.byKey(const ValueKey('my-profile-support')));
      await tester.pumpAndSettle();
      expect(find.text('常见问题'), findsOneWidget);
      expect(find.text('人工客服暂未开放'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profile fades continuously only near pinning and reverses, tools have no background',
    (tester) async {
      await mount(tester);
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      final pin = scroll.position.maxScrollExtent;
      double opacity(String id) =>
          tester.widget<Opacity>(find.byKey(ValueKey(id))).opacity;
      scroll.jumpTo(pin - 160);
      await tester.pump();
      expect(opacity('my-profile-info-opacity'), closeTo(1, .01));
      scroll.jumpTo(pin - 80);
      await tester.pump();
      expect(opacity('my-profile-info-opacity'), closeTo(.5, .01));
      expect(opacity('my-profile-exp-opacity'), closeTo(.5, .01));
      scroll.jumpTo(pin);
      await tester.pump();
      expect(opacity('my-profile-info-opacity'), closeTo(0, .01));
      expect(
        find.byKey(const ValueKey('my-profile-exp')).hitTestable(),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('my-profile-qr')).hitTestable(),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('my-profile-settings')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('my-profile-collapsed-name')),
        findsOneWidget,
      );
      final tools = tester.widget<Container>(
        find.byKey(const ValueKey('my-profile-top-tools')),
      );
      expect(tools.color, Colors.transparent);
      scroll.jumpTo(pin - 80);
      await tester.pump();
      expect(opacity('my-profile-info-opacity'), closeTo(.5, .01));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact services keep creator label on one line at 320 wide', (
    tester,
  ) async {
    await mount(tester, size: const Size(320, 640), textScale: 1.2);
    final services = find.byKey(const ValueKey('my-profile-services'));
    expect(tester.getSize(services).width, closeTo(320 * 718 / 750, .1));
    final label = tester.widget<Text>(find.text('创作者中心'));
    expect(label.maxLines, 1);
    expect(label.style!.letterSpacing, 0);
    expect(
      tester.getSize(find.byKey(const ValueKey('my-profile-creator'))).height,
      lessThan(65),
    );
    expect(find.text('写下此刻的心情…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mood lives below balance and edit result replaces empty prompt',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MyProfilePage(
              onOpenEditProfile: (name, signature, cover) async =>
                  EditableProfileResult(
                    nickname: name,
                    signature: '今天心情很好',
                    coverAsset: cover,
                  ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final mood = find.byKey(const ValueKey('my-profile-mood'));
      expect(
        tester.getTopLeft(mood).dy,
        greaterThan(
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('my-profile-asset-我的余额')),
              )
              .dy,
        ),
      );
      expect(
        tester.getBottomLeft(mood).dy,
        lessThan(tester.getTopLeft(find.text('24岁')).dy),
      );
      await tester.tap(mood);
      await tester.pumpAndSettle();
      expect(find.text('今天心情很好'), findsOneWidget);
      expect(find.text('写下此刻的心情…'), findsNothing);
    },
  );

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('profile fits $size with 200 percent text and switches pages', (
      tester,
    ) async {
      await mount(tester, size: size, textScale: 2);
      expect(tester.takeException(), isNull);
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('my-profile-tab-相册')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('my-profile-selected-tab-arrow-相册')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
