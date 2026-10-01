import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/home/data/home_content_repository.dart';
import 'package:kingclub/src/features/home/presentation/home_content_cards.dart';

import 'home_content_repository_test.dart' show homeFixture;

void main() {
  testWidgets(
    'three content types form unequal columns and open the selected hero',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final poster = HomeContent.parse(
        homeFixture(ref: 'poster', mode: 'poster'),
      );
      final article = HomeContent.parse(homeFixture(ref: 'article'));
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
      await tester.pumpAndSettle();
      expect(find.byType(HomeContentDetailPage), findsOneWidget);
      expect(find.text('Fixture body'), findsOneWidget);
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
