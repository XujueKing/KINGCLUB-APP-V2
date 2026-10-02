import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/home/data/home_content_repository.dart';
import 'package:kingclub/src/features/home/presentation/home_content_cards.dart';

import 'home_content_repository_test.dart' show homeFixture;

void main() {
  test('card flight expands directly from either column and finishes before the sheet', () {
    for (final left in [18.0, 201.0]) {
      final origin = Rect.fromLTWH(left, 400, 174, 241);
      const destination = Rect.fromLTWH(0, 0, 393, 545);
      final tween = HomeContentRectTween(begin: origin, end: destination);
      expect(tween.lerp(0), origin);
      final mid = tween.lerp(.5)!;
      final fraction =
          (mid.left - origin.left) / (destination.left - origin.left);
      expect(mid.top, closeTo(origin.top * (1 - fraction), .001));
      expect(
        mid.width,
        closeTo(
          origin.width + (destination.width - origin.width) * fraction,
          .001,
        ),
      );
      expect(tween.lerp(1), destination);
      expect(tween.lerp(1), destination);
    }
  });

  testWidgets(
    'three content types form unequal columns and open the selected hero',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final poster = HomeContent.parse(
        homeFixture(ref: 'poster', mode: 'poster'),
      );
      final articleRow = homeFixture(ref: 'article');
      (articleRow['document'] as Map)['backgroundColor'] = '#FFFFFF';
      final article = HomeContent.parse(articleRow);
      final video = HomeContent.parse(homeFixture(ref: 'video', mode: 'video'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: HomeContentMasonry(
                  items: [poster, article, video],
                  onOpen: (item) =>
                      openHomeContent(context, item, (_) async {}),
                  onLike: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final p = tester.getRect(find.byKey(const ValueKey('home-card-poster')));
      final a = tester.getRect(find.byKey(const ValueKey('home-card-article')));
      final v = tester.getRect(find.byKey(const ValueKey('home-card-video')));
      expect(a.top, p.top);
      expect(a.height, greaterThan(p.height));
      expect(v.left, p.left);
      expect(v.top, closeTo(p.bottom + 6, .1));
      expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
      expect(find.text('Fixture author'), findsNWidgets(2));
      expect(find.text('7'), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('home-card-article')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final flight = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == 'home-content-article',
      );
      expect(flight, findsWidgets);
      for (final hero in tester.widgetList<Hero>(flight)) {
        expect(hero.curve, Curves.linear);
      }
      await tester.pumpAndSettle();
      expect(find.byType(HomeContentDetailPage), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('home-detail-sheet'))).width,
        393,
      );
      expect(find.text('Fixture body'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text('Fixture body'))
            .style!
            .color!
            .computeLuminance(),
        lessThan(.5),
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const ValueKey('home-detail-panel')))
            .color,
        Colors.white,
      );
      final panel = find.byKey(const ValueKey('home-detail-panel'));
      final initialTop = tester.getTopLeft(panel).dy;
      await tester.dragFrom(
        Offset(150, initialTop + 25),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, lessThan(initialTop - 80));
      final shade = find.byKey(const ValueKey('home-detail-header-shade'));
      expect(tester.widget<Opacity>(shade).opacity, greaterThan(0));
      expect(
        tester.getCenter(find.byKey(const ValueKey('home-detail-close'))).dx,
        lessThan(393 / 4),
      );
      final drag = await tester.startGesture(
        Offset(150, tester.getTopLeft(panel).dy + 25),
      );
      await drag.moveBy(const Offset(0, 30));
      await tester.pump();
      await drag.moveBy(const Offset(0, 700));
      await tester.pump();
      expect(tester.getTopLeft(panel).dy, greaterThan(740));
      final stretch = find.byKey(const ValueKey('home-detail-image-stretch'));
      final matrix = tester.widget<Transform>(stretch).transform;
      final imageHeight = 393 / article.ratio;
      expect(matrix.entry(0, 0), greaterThan(1));
      expect(matrix.entry(0, 0), matrix.entry(1, 1));
      expect(
        imageHeight * matrix.entry(1, 1),
        closeTo(tester.getTopLeft(panel).dy, 1),
      );
      await drag.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, closeTo(initialTop, 1));
      expect(tester.widget<Opacity>(shade).opacity, closeTo(0, .001));
      expect(tester.widget<Transform>(stretch).transform.entry(0, 0), 1);
      // Release above the resting position: inertia crosses it afterwards.
      await tester.dragFrom(
        Offset(150, initialTop + 25),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.flingFrom(
        Offset(150, tester.getTopLeft(panel).dy + 25),
        const Offset(0, 100),
        1800,
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, lessThanOrEqualTo(initialTop + 1));
      // Interrupt a return with another pull, as in repeated real finger gestures.
      for (var attempt = 0; attempt < 2; attempt++) {
        final pull = await tester.startGesture(
          Offset(150, tester.getTopLeft(panel).dy + 20),
        );
        await pull.moveBy(const Offset(0, 30));
        await tester.pump();
        await pull.moveBy(const Offset(0, 160));
        await tester.pump();
        await pull.up();
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(panel).dy, closeTo(initialTop, 1));

      expect(find.byKey(const ValueKey('home-detail-close')), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('home-card-article'))),
        a,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
