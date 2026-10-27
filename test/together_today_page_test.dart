import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/club/data/together_feed.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/data/together_read_history.dart';
import 'package:kingclub/src/features/club/presentation/together_today_page.dart';
import 'package:kingclub/src/features/club/presentation/together_activity_page.dart';
import 'package:kingclub/src/features/club/presentation/together_artwork_contrast.dart';
import 'package:kingclub/src/features/club/presentation/together_play_page.dart';
import 'package:kingclub/src/features/club/presentation/together_activity_action.dart';
import 'package:kingclub/src/features/club/presentation/together_seat_cards.dart';

import 'together_play_test.dart' as old;

class Feed implements TogetherPlayRepository, TogetherFeedRepository {
  final calls = <TogetherFeedView>[];
  final filters = <String?>[];
  bool failDetail = false;
  bool includeOther = false;
  int detailCalls = 0;
  @override
  Future<TogetherFeedPage> feed({
    required TogetherFeedView view,
    String? cityCode,
    String? storeRef,
    DateTime? date,
    String? after,
  }) async {
    calls.add(view);
    filters.add(storeRef);
    return TogetherFeedPage([
      old.fixture(ref: 'future', day: 30, merchantHost: false),
      if (includeOther) old.fixture(ref: 'other', day: 30, merchantHost: false),
    ], null);
  }

  @override
  Future<TogetherParty> detail(String ref) async {
    detailCalls++;
    if (failDetail) throw StateError('offline');
    return old.fixture(ref: ref, day: 30, merchantHost: false);
  }

  @override
  Future<List<TogetherParty>> list({
    required String cityCode,
    required DateTime date,
  }) => throw StateError('daily path must stay unused');
}

Future<void> mount(
  WidgetTester tester,
  Feed repo, {
  Future<void> Function(TogetherParty)? join,
}) async {
  await tester.binding.setSurfaceSize(const Size(402, 874));
  await tester.pumpWidget(
    MaterialApp(
      theme: KingTheme.dark,
      locale: kingSupportedLocales.first,
      supportedLocales: kingSupportedLocales,
      localizationsDelegates: kingLocalizationDelegates,
      home: TogetherTodayPage(
        repository: repo,
        stores: old.Stores(),
        cityCode: '430200',
        cityName: '株洲市',
        account: 'member-test',
        readHistory: TogetherReadHistory('member-test'),
        onHome: () {},
        onSelectCity: () {},
        onAdmission: (_) async {},
        onJoin: join ?? (_) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });
  testWidgets('unselected cards stay hidden through both opaque transitions', (
    tester,
  ) async {
    final repo = Feed()..includeOther = true;
    await mount(tester, repo);
    final other = find.byKey(
      const ValueKey('today-card-visibility-other'),
      skipOffstage: false,
    );
    expect(tester.widget<Opacity>(other).opacity, 1);
    await tester.tap(find.byKey(const ValueKey('together-join-future')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pump();
    expect(tester.widget<Opacity>(other).opacity, 0);
    expect(
      tester
          .widget<Opacity>(
            find.byKey(
              const ValueKey('today-header-visibility'),
              skipOffstage: false,
            ),
          )
          .opacity,
      0,
    );
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(TogetherActivityPage),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor?.a, 1);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('together-close-detail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.widget<Opacity>(other).opacity, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(other).opacity, 1);
    expect(repo.calls, [TogetherFeedView.recommendations]);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'both card trees survive Hero handoff without remounting images',
    (tester) async {
      final repo = Feed();
      await mount(tester, repo);
      final cards = find.byType(TogetherArtworkContrast, skipOffstage: false);
      final source = tester.state(cards);
      await tester.tap(find.byKey(const ValueKey('together-join-future')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));
      await tester.pump();
      final states = tester.stateList(cards).toList();
      expect(states, hasLength(3));
      expect(states, contains(same(source)));
      final target = states[1];
      await tester.pumpAndSettle();
      expect(tester.stateList(cards), contains(same(target)));
      await tester.tap(find.byKey(const ValueKey('together-close-detail')));
      await tester.pumpAndSettle();
      expect(tester.state(cards), same(source));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'flight grows only artwork while footer controls keep their size',
    (tester) async {
      await mount(tester, Feed());
      final source = find.byKey(const ValueKey('together-join-future'));
      final before = tester.getRect(
        find.descendant(
          of: source,
          matching: find.byKey(const ValueKey('together-action-pill')),
        ),
      );
      await tester.tap(source);
      await tester.pump();
      Future<void> checkFlight() async {
        final flight = find.byKey(
          const ValueKey('together-card-flight-content'),
        );
        expect(flight, findsOneWidget);
        final button = find.descendant(
          of: flight,
          matching: find.byKey(const ValueKey('together-action-pill')),
        );
        expect(tester.getRect(button).size, before.size);
        final seats = tester.widget<TogetherMemberAvatar>(
          find.descendant(
            of: flight,
            matching: find.byType(TogetherMemberAvatar),
          ),
        );
        expect(seats.size, 48);
        final title = tester.widget<Text>(
          find.descendant(
            of: flight,
            matching: find.byKey(
              const ValueKey('together-editorial-title-future'),
            ),
          ),
        );
        expect(title.style!.fontSize, 24);
        expect(
          find.descendant(
            of: flight,
            matching: find.byType(TogetherActivityAction),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: flight, matching: find.byType(FittedBox)),
          findsNothing,
        );
        expect(
          tester
              .getRect(
                find.descendant(
                  of: flight,
                  matching: find.byType(TogetherMemberAvatar),
                ),
              )
              .size,
          const Size(48, 48),
        );
      }

      await tester.pump(const Duration(milliseconds: 90));
      await checkFlight();
      await tester.pump(const Duration(milliseconds: 90));
      await checkFlight();
      await tester.pumpAndSettle();
      final detail = find.byType(TogetherActivityPage);
      final detailPill = find.descendant(
        of: detail,
        matching: find.byKey(const ValueKey('together-action-pill')),
      );
      expect(tester.getRect(detailPill).size, before.size);
      await tester.tap(find.byKey(const ValueKey('together-close-detail')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await checkFlight();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('expansion keeps content without blur or loading indicators', (
    tester,
  ) async {
    final repo = Feed();
    await mount(tester, repo);
    await tester.tap(find.byKey(const ValueKey('together-join-future')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.pump();
    expect(repo.detailCalls, 0);
    expect(find.text('参加须知'), findsNothing);
    expect(
      find.byKey(const ValueKey('together-card-flight-content')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is BackdropFilter && widget.enabled,
      ),
      findsNothing,
    );
    await tester.pumpAndSettle();
    expect(repo.detailCalls, 1);
    expect(find.text('参加须知'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('together-close-detail')));
    await tester.pumpAndSettle();
    expect(repo.calls, [TogetherFeedView.recommendations]);
    expect(find.text('加入'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('together-card-flight-content')),
      findsNothing,
    );
  });
  testWidgets(
    'Today uses cross-date feed and menu preserves exact classification',
    (tester) async {
      final repo = Feed();
      await mount(tester, repo);
      expect(find.text('今日'), findsOneWidget);
      expect(repo.calls, [TogetherFeedView.recommendations]);
      expect(find.byType(TogetherAvailableRow), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('today-menu')));
      await tester.pumpAndSettle();
      for (final label in ['返回首页', '切换城市', '切换商店', '选择时间', '今日推荐']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'first View opens detail, marks only successful read, Join buys directly',
    (tester) async {
      var buys = 0;
      final repo = Feed();
      await mount(
        tester,
        repo,
        join: (_) async {
          buys++;
        },
      );
      expect(find.text('查看'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-join-future')));
      await tester.pumpAndSettle();
      expect(find.byType(TogetherActivityPage), findsOneWidget);
      final detail = find.descendant(
        of: find.byType(TogetherActivityPage),
        matching: find.byKey(const ValueKey('together-join-future')),
      );
      expect(
        find.descendant(of: detail, matching: find.text('加入')),
        findsOneWidget,
      );
      await tester.tap(detail);
      await tester.pumpAndSettle();
      expect(buys, 1);
      await tester.tap(find.byKey(const ValueKey('together-close-detail')));
      await tester.pumpAndSettle();
      expect(find.text('加入'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-join-future')));
      await tester.pumpAndSettle();
      expect(buys, 2);
      expect(find.byType(TogetherActivityPage), findsNothing);
      // Card body continues to show detail even after View has unlocked Join.
      await tester.tap(find.byKey(const ValueKey('together-card-future')));
      await tester.pumpAndSettle();
      expect(find.byType(TogetherActivityPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed detail never unlocks direct purchase', (tester) async {
    final repo = Feed()..failDetail = true;
    await mount(tester, repo);
    await tester.tap(find.byKey(const ValueKey('together-join-future')));
    await tester.pumpAndSettle();
    expect(find.textContaining('暂时无法加载活动详情'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('together-close-detail')));
    await tester.pumpAndSettle();
    expect(find.text('查看'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('unused ticket menu opens original ticket layout', (
    tester,
  ) async {
    final repo = Feed();
    await mount(tester, repo);
    await tester.tap(find.byKey(const ValueKey('today-avatar-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('可用活动券'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, TogetherFeedView.tickets);
    expect(find.byType(TogetherPartyCard), findsOneWidget);
    expect(find.text('返回今日'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'viewed activity preference is bounded and isolated by member',
    () async {
      final a = TogetherReadHistory('a');
      await a.mark('event-one');
      expect(await TogetherReadHistory('a').load(), contains('event-one'));
      expect(await TogetherReadHistory('b').load(), isEmpty);
    },
  );
}
