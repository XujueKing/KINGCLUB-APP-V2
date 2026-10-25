import 'package:kingclub/src/core/design_system/king_localizations.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/data/together_party_draft.dart';
import 'package:kingclub/src/features/club/data/together_store.dart';
import 'package:kingclub/src/features/club/presentation/together_play_page.dart';
import 'package:kingclub/src/features/club/presentation/together_party_create_page.dart';
import 'package:kingclub/src/features/club/presentation/together_review_page.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/core/design_system/king_components.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';
import 'package:kingclub/src/features/club/presentation/positioning_card_label.dart';
import 'package:kingclub/src/features/club/presentation/together_date_picker.dart';
import 'package:kingclub/src/features/club/presentation/together_ticket_page.dart';

class Stores implements TogetherStoreRepository {
  @override
  Future<List<TogetherStore>> list({required String cityCode}) async => const [
    TogetherStore(ref: 'a', name: '门店甲', cityCode: '430200', address: '地址甲'),
    TogetherStore(ref: 'b', name: '门店乙', cityCode: '430200', address: '地址乙'),
    TogetherStore(ref: 'c', name: '外市门店', cityCode: '430100', address: '外市地址'),
  ];
  @override
  Future<List<TogetherTable>> tables({
    required String storeRef,
  }) async => const [
    TogetherTable(ref: 't-a', storeRef: 'a', name: '甲店卡座', maximumSeats: 8),
    TogetherTable(ref: 't-b', storeRef: 'b', name: '乙店卡座', maximumSeats: 12),
  ];
}

TogetherParty fixture({
  String ref = 'night',
  String city = '430200',
  TogetherFeeMode fee = TogetherFeeMode.aa,
  TogetherJoinState state = TogetherJoinState.available,
  int capacity = 10,
  int count = 3,
  int day = 2,
  String? assignedTable,
  String? ticketNumber,
  String? admissionCode,
  bool admissionUsed = false,
  bool merchantHost = true,
  List<TogetherParticipant>? participants,
  List<TogetherGender> seatGenders = const [],
  String? posterUrl,
  List<String> posterUrls = const [],
  bool? eligible,
  List<String> eligibilityReasons = const [],
  int? personalPriceMinor,
}) => TogetherParty(
  ref: ref,
  theme: ref == 'night' ? '周末微醺交友局' : '一起听歌 · 认识新朋友',
  cityCode: city,
  cityName: '株洲市',
  storeRef: 'fixture-store',
  storeName: '样例门店',
  assignedTable: assignedTable,
  ticketNumber: ticketNumber,
  admissionCode: admissionCode,
  admissionUsed: admissionUsed,
  startsAt: DateTime(2026, 10, day, 21),
  endsAt: DateTime(2026, 10, day + 1, 2),
  hostName: '样例发起人',
  merchantHost: merchantHost,
  place: '样例活动地点',
  capacity: capacity,
  seatGenders: seatGenders,
  posterUrl: posterUrl,
  posterUrls: posterUrls,
  eligible: eligible,
  eligibilityReasons: eligibilityReasons,
  personalPriceMinor: personalPriceMinor,
  participants:
      participants ??
      List.generate(count, (i) => TogetherParticipant(name: '样例会员$i')),
  feeMode: fee,
  priceMinor: 38850,
  state: state,
  description: '一起听音乐、认识新朋友。活动内容以本场说明为准。',
  rules: '报名与取消规则将在确认报名时展示。',
);

class Repository implements TogetherPlayRepository {
  final requests = <Completer<List<TogetherParty>>>[];
  final dates = <DateTime>[];
  TogetherParty current = fixture();
  @override
  Future<List<TogetherParty>> list({
    required String cityCode,
    required DateTime date,
  }) {
    dates.add(date);
    final request = Completer<List<TogetherParty>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<TogetherParty> detail(String ref) async => current;
}

void main() {
  test(
    'editorial headline balances Chinese titles without a one-character orphan',
    () {
      const title = '测试·生日快乐，今晚我请客';
      const style = TextStyle(fontSize: 28, fontWeight: FontWeight.w700);
      final text = togetherEditorialHeadline(
        title,
        style,
        313,
        TextScaler.noScaling,
        TextDirection.ltr,
      );
      final lines = text.split('\n');
      expect(lines, hasLength(2));
      expect(lines.every((line) => line.characters.length > 3), isTrue);
      expect(lines.last.startsWith('，'), isFalse);
      expect(lines.join(), title);
      expect(
        togetherEditorialHeadline(
          '周末微醺',
          style,
          313,
          TextScaler.noScaling,
          TextDirection.ltr,
        ),
        '周末微醺',
      );
    },
  );

  testWidgets('joined seats without photos use full gender symbols', (
    tester,
  ) async {
    final party = fixture(
      capacity: 4,
      participants: const [
        TogetherParticipant(
          name: '男会员',
          seatIndex: 0,
          gender: TogetherGender.male,
        ),
        TogetherParticipant(
          name: '女会员',
          seatIndex: 2,
          gender: TogetherGender.female,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TogetherParticipants(party: party)),
      ),
    );
    await tester.pumpAndSettle();
    for (final index in [0, 2]) {
      final seat = find.byKey(ValueKey('seat-night-$index'));
      final image = tester.widget<Image>(
        find.descendant(of: seat, matching: find.byType(Image)),
      );
      expect(
        (image.image as AssetImage).assetName,
        index == 0 ? 'assets/legacy/aa/man2.png' : 'assets/legacy/aa/woman.png',
      );
      expect(
        find.descendant(of: seat, matching: find.byIcon(Icons.person)),
        findsNothing,
      );
    }
  });

  testWidgets(
    'detail footer fits the real full-width button theme on a phone',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final party = fixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: KingTheme.dark,
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: TogetherPartyDetailPage(
            party: party,
            repository: Repository()..current = party,
            onJoin: (_) async {},
            onAdmission: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(find.byType(FilledButton));
      expect(button.height, lessThanOrEqualTo(60));
      expect(button.width, lessThan(180));
      expect(button.bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unmatched activity explains requirements and disables joining', (
    tester,
  ) async {
    var attempts = 0;
    final party = fixture(eligible: false, eligibilityReasons: ['活动年龄上限为29周岁']);
    await tester.pumpWidget(
      MaterialApp(
        locale: kingSupportedLocales.first,
        supportedLocales: kingSupportedLocales,
        localizationsDelegates: kingLocalizationDelegates,
        home: TogetherPartyDetailPage(
          party: party,
          repository: Repository()..current = party,
          onJoin: (_) async {
            attempts++;
          },
          onAdmission: (_) async {},
        ),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('活动年龄上限为29周岁'));
    await tester.pumpAndSettle();
    expect(find.text('活动年龄上限为29周岁'), findsOneWidget);
    expect(attempts, 0);
    expect(
      fixture(state: TogetherJoinState.joined, eligible: false).canAct,
      isTrue,
    );
  });
  testWidgets(
    'detail posters swipe, show page count and keep legacy single image',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final party = fixture(
        posterUrl: 'https://example.com/old.jpg',
        posterUrls: [
          'https://example.com/one.jpg',
          'https://example.com/two.jpg',
          'https://example.com/three.jpg',
        ],
      );
      expect(party.detailPosters.length, 3);
      expect(party.detailPosters, isNot(contains(party.posterUrl)));
      expect(fixture(posterUrl: 'https://example.com/old.jpg').detailPosters, [
        'https://example.com/old.jpg',
      ]);
      expect(fixture().detailPosters, isEmpty);
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: TogetherPartyDetailPage(
            party: party,
            repository: Repository()..current = party,
            onJoin: (_) async {},
            onAdmission: (_) async {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('1/3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-260, 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('2/3'), findsOneWidget);
      await tester.drag(find.byType(PageView), const Offset(-260, 0));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('3/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'back position matches chat across safe areas and dates keep taps',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final size in [const Size(375, 812), const Size(402, 874)]) {
        tester.view.physicalSize = size;
        final safeTop = size.width == 375 ? 44.0 : 62.0;
        Widget app(Widget page) => MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: EdgeInsets.only(top: safeTop),
              viewPadding: EdgeInsets.only(top: safeTop),
            ),
            child: child!,
          ),
          home: page,
        );
        await tester.pumpWidget(
          app(
            Scaffold(
              body: SafeArea(
                child: Column(
                  children: [LegacyMessagingHeader(title: '会话', onBack: () {})],
                ),
              ),
            ),
          ),
        );
        final chatBack = tester.getRect(find.byType(KingBackButton));
        final chatTitleRect = tester.getRect(find.text('\u4f1a\u8bdd'));
        final chatTitleStyle = tester
            .widget<Text>(find.text('\u4f1a\u8bdd'))
            .style!;
        var backs = 0;
        await tester.pumpWidget(app(TogetherReviewPage(onBack: () => backs++)));
        await tester.pumpAndSettle();
        expect(tester.getRect(find.byType(KingBackButton)), chatBack);
        final title = find.byKey(const ValueKey('together-title'));
        final titleStyle = tester.widget<Text>(title).style!;
        expect(
          tester.getRect(title).center.dy,
          closeTo(chatTitleRect.center.dy, 0.5),
        );
        expect(tester.getRect(title).height, chatTitleRect.height);
        expect(titleStyle.color, chatTitleStyle.color);
        expect(titleStyle.fontSize, chatTitleStyle.fontSize);
        expect(titleStyle.fontWeight, chatTitleStyle.fontWeight);
        expect(
          tester.getCenter(find.byKey(const ValueKey('together-title'))).dy,
          chatBack.center.dy,
        );
        await tester.tap(find.byKey(const ValueKey('together-date-1')));
        await tester.pumpAndSettle();
        final firstDate = find.byKey(const ValueKey('together-date-box-0'));
        await tester.tapAt(tester.getTopLeft(firstDate) + const Offset(2, 2));
        await tester.pumpAndSettle();
        expect(backs, 0);
        expect(
          (tester.widget<Container>(firstDate).decoration as BoxDecoration)
              .color,
          const Color(0xFFC9B69E),
        );
        await tester.tap(find.byType(KingBackButton));
        expect(backs, 1);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'flat ticket preserves all square seats and member avatar placement',
    (tester) async {
      final party = fixture(
        capacity: 14,
        participants: const [
          TogetherParticipant(
            name: 'Member',
            seatIndex: 7,
            gender: TogetherGender.female,
            avatar: 'assets/legacy/home/legacy_poster_handsome.webp',
          ),
        ],
        seatGenders: List.generate(
          14,
          (i) => i < 7 ? TogetherGender.male : TogetherGender.female,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          theme: KingTheme.dark.copyWith(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 339,
                child: TogetherPartyCard(party: party, onTap: () {}),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final storeText = tester.widget<Text>(find.text(party.storeName).last);
      expect(storeText.style?.fontFamily, 'CupertinoSystemText');
      expect(storeText.style?.color, const PositioningCardLabel().color);
      final priceText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.textSpan?.toPlainText() == '￥388.50/人',
        ),
      );
      expect(priceText.textSpan?.style?.fontFamily, 'CupertinoSystemText');
      final cardSize = tester.getSize(
        find.byKey(const ValueKey('together-card-night')),
      );
      expect(cardSize.width / cardSize.height, closeTo(690 / 232, .01));
      final logo = tester.getRect(find.byType(TogetherStoreLogo));
      final label = tester.getRect(find.byType(PositioningCardLabel));
      // Extra ticket height belongs inside the merchant row, not the outer rim.
      expect(label.top - logo.bottom, closeTo(8.5 * 339 / 345, .1));
      for (var i = 0; i < 14; i++) {
        final seat = find.byKey(ValueKey('seat-night-$i'));
        expect(seat, findsOneWidget);
        final size = tester.getSize(seat);
        expect(size.width, size.height);
      }
      final image = tester.widget<Image>(
        find.descendant(
          of: find.byKey(const ValueKey('seat-night-7')),
          matching: find.byType(Image),
        ),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/legacy/home/legacy_poster_handsome.webp',
      );
      expect(find.byType(CircleAvatar), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legacy date geometry is independent of app body typography', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Rect? original;
    for (final body in [
      const TextStyle(fontSize: 15, height: 1.6),
      const TextStyle(
        fontSize: 28,
        height: 2,
        letterSpacing: 3,
        fontFamily: 'monospace',
        fontWeight: FontWeight.w800,
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          theme: ThemeData(textTheme: TextTheme(bodyMedium: body)),
          home: Scaffold(
            body: TogetherDateStrip(
              firstDate: DateTime(2026, 10, 2),
              lastDate: DateTime(2026, 10, 31),
              selectedDate: DateTime(2026, 10, 2),
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.getRect(
        find.byKey(const ValueKey('together-date-box-0')),
      );
      expect(box.height, closeTo(393 * 80 / 750, .01));
      if (original != null) expect(box, original);
      original = box;
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets(
    'calendar crosses year, updates query and strip, cancel preserves selection',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = Repository();
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          theme: KingTheme.dark,
          home: TogetherPlayPage(
            repository: repository,
            cityCode: '430200',
            cityName: '株洲市',
            today: DateTime(2026, 12, 30),
            onBack: () {},
            onCreate: () {},
            onJoin: (_) async {},
            onAdmission: (_) async {},
          ),
        ),
      );
      repository.requests.last.complete([]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('together-calendar-open')));
      await tester.pumpAndSettle();
      final past = find.byKey(const ValueKey('together-calendar-2026-12-29'));
      expect(tester.widget<InkWell>(past).onTap, isNull);
      final next = find.byKey(const ValueKey('together-calendar-2027-1-25'));
      await tester.drag(
        find.byKey(const ValueKey('together-calendar-months')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pump();
      expect(repository.dates.last, DateTime(2027, 1, 25));
      repository.requests.last.complete([]);
      await tester.pumpAndSettle();
      expect(find.byType(TogetherCalendarSheet), findsNothing);
      final selected = find.byKey(const ValueKey('together-date-26'));
      expect(selected.hitTestable(), findsOneWidget);
      final requestCount = repository.requests.length;
      await tester.tap(find.byKey(const ValueKey('together-calendar-open')));
      await tester.pumpAndSettle();
      expect(next.hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-calendar-close')));
      await tester.pumpAndSettle();
      expect(repository.requests.length, requestCount);
      expect(repository.dates.last, DateTime(2027, 1, 25));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'explicit landing review fits small screens and does not enter later pages',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: TogetherReviewPage(onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('布局样例 · 非真实活动'), findsNothing);
      expect(find.text('AA邀请'), findsOneWidget);
      expect(find.text('卡颜AA交友局'), findsOneWidget);
      expect(find.byType(TogetherPartyCard), findsOneWidget);
      expect(find.text('888'), findsOneWidget);
      expect(find.byType(TogetherAvailableRow), findsNWidgets(2));
      // Shared 56dp header + compact 6dp top gap + 40dp dates + 15dp bottom gap.
      final ticket = tester.getRect(
        find.byKey(const ValueKey('together-card-friends')),
      );
      expect(ticket.left, closeTo(30 * .5, .1));
      expect(ticket.top, closeTo(117, .1));
      expect(ticket.width, closeTo(690 * .5, .1));
      expect(ticket.height, closeTo(232 * .5, .1));
      final date = tester.getRect(
        find.byKey(const ValueKey('together-date-box-0')),
      );
      expect(date.top, closeTo(62, .1));
      final nextRow = tester.getRect(
        find.byKey(const ValueKey('together-heading-music')),
      );
      final reminder = tester.getRect(
        find.byKey(const ValueKey('together-use-reminder-friends')),
      );
      expect(reminder.top - ticket.bottom, closeTo(20 * .5, .1));
      expect(nextRow.top - reminder.bottom, closeTo(30 * .5, .1));
      expect(find.text('商家发起 · KINGCLUB官方'), findsNothing);
      expect(
        find.byKey(const ValueKey('together-official-music')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('together-editorial-subtitle-music')),
        findsOneWidget,
      );
      expect(find.text('男士AA，女士免票；请按时到场，文明交流。'), findsNothing);
      expect(find.text('抢位'), findsNothing);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('together-card-friends')))
            .dy,
        lessThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('together-card-music')))
              .dy,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('together-card-friends')));
      await tester.pumpAndSettle();
      expect(find.byType(TogetherPartyDetailPage), findsNothing);
      expect(find.byType(TogetherTicketPage), findsOneWidget);
      await tester.tap(find.byType(KingBackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('together-date-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('together-card-friends')), findsNothing);
      expect(find.byType(TogetherPartyCard), findsNothing);
      expect(find.textContaining('请按时到场并出示入场码'), findsNothing);
      expect(
        tester
            .getTopLeft(find.byKey(const ValueKey('together-heading-music')))
            .dy,
        closeTo(ticket.top, .1),
      );
      expect(tester.takeException(), isNull);
    },
  );
  test('only a confirmed assigned table qualifies as a positioning ticket', () {
    expect(fixture(state: TogetherJoinState.joined).hasAdmissionTicket, isTrue);
    expect(
      fixture(state: TogetherJoinState.pendingPayment).hasAdmissionTicket,
      isFalse,
    );
    expect(fixture(state: TogetherJoinState.joined).hasAssignedTable, isFalse);
    expect(fixture(assignedTable: '888').hasAssignedTable, isFalse);
    expect(
      fixture(
        state: TogetherJoinState.joined,
        assignedTable: '888',
      ).hasAssignedTable,
      isTrue,
    );
  });

  testWidgets('paid ticket without table is above unpaid invitations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = Repository();
    await tester.pumpWidget(
      MaterialApp(
        locale: kingSupportedLocales.first,
        supportedLocales: kingSupportedLocales,
        localizationsDelegates: kingLocalizationDelegates,
        home: TogetherPlayPage(
          repository: repository,
          cityCode: '430200',
          cityName: '株洲市',
          today: DateTime(2026, 10, 2),
          onBack: () {},
          onCreate: () {},
          onJoin: (_) async {},
          onAdmission: (_) async {},
        ),
      ),
    );
    repository.requests.single.complete([
      fixture(ref: 'pending', state: TogetherJoinState.pendingPayment),
      fixture(state: TogetherJoinState.joined),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(TogetherPartyCard), findsOneWidget);
    expect(find.text('待分配'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('together-use-reminder-night')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('together-use-reminder-pending')),
      findsNothing,
    );
    expect(find.text('继续支付'), findsNothing);
    expect(
      find.byKey(const ValueKey('together-summary-open-pending')),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('together-card-night'))).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('together-card-pending')))
            .dy,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'merchant invitation omits store metadata and opens existing detail',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      for (final state in [
        TogetherJoinState.available,
        TogetherJoinState.full,
        TogetherJoinState.closed,
        TogetherJoinState.cancelled,
      ]) {
        final party = fixture(state: state);
        await tester.pumpWidget(
          MaterialApp(
            locale: kingSupportedLocales.first,
            supportedLocales: kingSupportedLocales,
            localizationsDelegates: kingLocalizationDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TogetherAvailableRow(party: party, onTap: () => taps++),
              ),
            ),
          ),
        );
        expect(find.text(party.storeName), findsNothing);
        expect(find.text('商家发起 · ${party.hostName}'), findsNothing);
        expect(find.text(party.theme), findsNWidgets(3));
        expect(find.text(party.rules), findsNothing);
        expect(find.byType(BackdropFilter), findsOneWidget);
        expect(find.text(party.priceLabel), findsOneWidget);
        final action = find.byKey(
          const ValueKey('together-invitation-action-night'),
        );
        expect(action, findsNothing);
        expect(find.byType(TogetherParticipants), findsNothing);
        expect(find.byType(TogetherStoreLogo), findsNothing);
        if (state == TogetherJoinState.available) {
          await tester.tap(find.byKey(const ValueKey('together-card-night')));
          expect(taps, 1);
          await tester.ensureVisible(
            find.byKey(const ValueKey('together-summary-open-night')),
          );
          await tester.tap(
            find.byKey(const ValueKey('together-summary-open-night')),
          );
          expect(taps, 2);
        }
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('AA footer has only seats and adapts to narrow and wide phones', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 390.0, 600.0]) {
      tester.view.physicalSize = Size(width, 1100);
      final party = fixture(merchantHost: false, capacity: 12);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TogetherAvailableRow(party: party, onTap: () {}),
            ),
          ),
        ),
      );
      final footer = find.byKey(const ValueKey('together-seats-footer-night'));
      expect(footer, findsOneWidget);
      expect(
        find.descendant(of: footer, matching: find.byType(Text)),
        findsNothing,
      );
      expect(find.byType(TogetherStoreLogo), findsNothing);
      expect(find.text(party.storeName), findsNothing);
      expect(find.text(party.priceLabel), findsNothing);
      expect(find.text('查看'), findsNothing);
      await tester.ensureVisible(footer);
      await tester.drag(footer, const Offset(-900, 0));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('seat-night-11')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('iPhone editorial geometry matches measured App Store card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final party = fixture(merchantHost: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 393 * .04),
              child: TogetherAvailableRow(party: party, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    final card = tester.getRect(
      find.byKey(const ValueKey('together-card-night')),
    );
    expect(card.left, closeTo(20, .4));
    expect(card.width, closeTo(353, .8));
    final heading = tester.widget<Text>(
      find.byKey(const ValueKey('together-editorial-title-night')),
    );
    final kicker = tester.widget<Text>(
      find.byKey(const ValueKey('together-kicker-night')),
    );
    final subtitle = tester.widget<Text>(
      find.byKey(const ValueKey('together-editorial-subtitle-night')),
    );
    expect(kicker.style!.fontSize, closeTo(12, .1));
    expect(subtitle.style!.fontSize, closeTo(13, .1));
    expect(kicker.style!.color!.a, closeTo(.6, .01));
    expect(subtitle.style!.color!.a, closeTo(.6, .01));
    expect(heading.style!.fontSize, closeTo(28, .1));
    expect(heading.style!.fontFamily, 'CupertinoSystemDisplay');
    final hero = tester.getRect(
      find.byKey(const ValueKey('together-artwork-region-night')),
    );
    expect(hero.height, closeTo(357, 1));
    final footer = tester.getRect(find.byType(BackdropFilter));
    expect(footer.height, closeTo(78, .2));
    expect(
      find.byKey(const ValueKey('seat-night-4')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('seat-night-5')).hitTestable(),
      findsNothing,
    );
    final fifth = tester.getRect(find.byKey(const ValueKey('seat-night-4')));
    expect(fifth.right, closeTo(card.right - 20, .2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('store selection filters city and resets table on store change', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: kingSupportedLocales.first,
        supportedLocales: kingSupportedLocales,
        localizationsDelegates: kingLocalizationDelegates,
        home: TogetherPartyCreatePage(
          cityCode: '430200',
          cityName: '株洲市',
          stores: Stores(),
          onBack: () {},
          loadLibrary: () async => [],
          uploadArtwork: () async => null,
          onReview: (_) async {},
        ),
      ),
    );
    await tester.tap(find.text('选择活动门店'));
    await tester.pumpAndSettle();
    expect(find.text('外市门店'), findsNothing);
    await tester.tap(find.text('门店甲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('选择卡座 / 桌台（可选）'));
    await tester.pumpAndSettle();
    expect(find.text('乙店卡座'), findsNothing);
    await tester.tap(find.text('甲店卡座'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('门店甲'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('门店乙'));
    await tester.pumpAndSettle();
    expect(find.text('甲店卡座'), findsNothing);
    expect(find.text('选择卡座 / 桌台（可选）'), findsOneWidget);
    expect(find.text('地址乙'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('creation blocks capacity overflow and unreviewed artwork; money stays integer cents', () {
    TogetherPartyDraft draft(
      TogetherArtworkStatus status, {
      int seats = 10,
      String storeCity = '430200',
      String tableStore = 'fixture-store',
    }) {
      final artwork = TogetherArtwork(
        ref: 'fixture',
        name: 'Test',
        url: 'https://example.test/image.webp',
        status: status,
      );
      return TogetherPartyDraft(
        theme: '聚会',
        cityCode: '430200',
        store: TogetherStore(
          ref: 'fixture-store',
          name: '样例门店',
          cityCode: storeCity,
          address: '样例地点',
        ),
        place: '样例地点',
        startsAt: DateTime(2026, 10, 10),
        endsAt: DateTime(2026, 10, 11),
        capacity: 10,
        feeMode: TogetherFeeMode.aa,
        priceMinor: 38850,
        totalCostMinor: 388500,
        description: '',
        background: artwork,
        poster: artwork,
        table: TogetherTable(
          ref: 'fixture-table',
          storeRef: tableStore,
          name: '样例桌台',
          maximumSeats: seats,
        ),
      );
    }

    final now = DateTime(2026, 10, 2);
    expect(
      draft(TogetherArtworkStatus.approved, seats: 8).validate(now: now),
      '总人数不能超过桌台容量',
    );
    expect(
      draft(TogetherArtworkStatus.pending).validate(now: now),
      '背景和海报审核通过后才能发布',
    );
    expect(draft(TogetherArtworkStatus.approved).validate(now: now), isNull);
    expect(TogetherPartyDraft.parseMoney('388.50'), 38850);
    expect(TogetherPartyDraft.parseMoney('0.01'), 1);
    expect(TogetherPartyDraft.parseMoney('1.001'), isNull);
    expect(TogetherPartyDraft.parseMoney('-1'), isNull);
    expect(
      draft(
        TogetherArtworkStatus.approved,
        storeCity: '430100',
      ).validate(now: now),
      '请选择当前城市的门店',
    );
    expect(
      draft(
        TogetherArtworkStatus.approved,
        tableStore: 'another-store',
      ).validate(now: now),
      '请重新选择该门店的桌台',
    );
  });
  test('fee labels preserve cents and free attendance is not joined', () {
    expect(fixture().priceLabel, '¥388.50/人');
    expect(fixture(fee: TogetherFeeMode.menPay).priceLabel, '¥388.50/男士');
    final free = fixture(fee: TogetherFeeMode.hostTreat);
    expect(free.priceLabel, '免费参加');
    expect(free.actionLabel, '抢定');
    expect(fixture(capacity: 3).actionLabel, '已满员');
    expect(
      fixture(capacity: 3, state: TogetherJoinState.joined).actionLabel,
      '入场码',
    );
    expect(togetherTimeRange(free), '10.02 21:00–10.03 02:00');
    expect(togetherCardTimeRange(free), '10.02 21:00–02:00');
  });

  testWidgets('date switch rejects late responses and other cities', (
    tester,
  ) async {
    final repo = Repository();
    await tester.pumpWidget(
      MaterialApp(
        locale: kingSupportedLocales.first,
        supportedLocales: kingSupportedLocales,
        localizationsDelegates: kingLocalizationDelegates,
        home: TogetherPlayPage(
          repository: repo,
          cityCode: '430200',
          cityName: '株洲市',
          onBack: () {},
          onCreate: () {},
          today: DateTime(2026, 10, 2),
          onJoin: (_) async {},
          onAdmission: (_) async {},
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('together-date-1')));
    repo.requests[1].complete([
      fixture(day: 3),
      fixture(ref: 'wrong-city', city: '430100', day: 3),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('together-card-night')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('together-card-wrong-city')),
      findsNothing,
    );
    repo.requests[0].complete([]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('together-card-night')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'full admission recheck blocks joining and joined card shows QR',
    (tester) async {
      final repo = Repository();
      var joined = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: TogetherPartyDetailPage(
            party: fixture(),
            repository: repo,
            onJoin: (_) async {
              joined++;
            },
            onAdmission: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      repo.current = fixture(state: TogetherJoinState.full);
      await tester.tap(find.text('抢定'));
      await tester.pumpAndSettle();
      expect(joined, 0);
      expect(find.text('已满员'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          locale: kingSupportedLocales.first,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: TogetherPartyCard(
                party: fixture(state: TogetherJoinState.joined),
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('together-admission-icon')),
        findsOneWidget,
      );
      expect(find.text('抢定'), findsNothing);
      expect(find.text(fixture().theme), findsOneWidget);
      expect(find.text('10.02 21:00–02:00'), findsOneWidget);
      expect(find.text('￥388.50/人', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ticket date and QR align with label for short and long themes', (
    tester,
  ) async {
    for (final width in [320.0, 370.0]) {
      for (final ref in ['night', 'long-theme']) {
        final party = fixture(ref: ref, state: TogetherJoinState.joined);
        await tester.pumpWidget(
          MaterialApp(
            locale: kingSupportedLocales.first,
            supportedLocales: kingSupportedLocales,
            localizationsDelegates: kingLocalizationDelegates,
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  child: TogetherPartyCard(party: party, onTap: () {}),
                ),
              ),
            ),
          ),
        );
        final label = tester.getRect(find.byType(PositioningCardLabel));
        final date = tester.getRect(find.text(togetherCardTimeRange(party)));
        final qr = tester.getRect(
          find.byKey(const ValueKey('together-admission-icon')),
        );
        expect(date.bottom, closeTo(label.bottom, .1));
        expect(qr.bottom, closeTo(label.bottom, .1));
        final theme = tester.widget<Text>(find.text(party.theme));
        expect(theme.style?.fontSize, anyOf(12, 14));
        expect(theme.style?.fontWeight, FontWeight.w600);
        expect(theme.style?.color, const Color(0xFFC9B69E));
        final seats = tester.getRect(find.byType(TogetherParticipants));
        expect(
          tester.getRect(find.text(party.theme)).top,
          greaterThan(seats.bottom),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
