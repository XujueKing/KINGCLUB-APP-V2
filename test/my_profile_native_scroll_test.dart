import 'package:flutter/material.dart';
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
