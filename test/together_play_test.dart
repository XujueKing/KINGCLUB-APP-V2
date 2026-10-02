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
import 'package:kingclub/src/features/club/presentation/together_date_picker.dart';

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
  List<TogetherParticipant>? participants,
  List<TogetherGender> seatGenders = const [],
}) => TogetherParty(
  ref: ref,
  theme: ref == 'night' ? '周末微醺交友局' : '一起听歌 · 认识新朋友',
  cityCode: city,
  cityName: '株洲市',
  storeRef: 'fixture-store',
  storeName: '样例门店',
  startsAt: DateTime(2026, 10, day, 21),
  endsAt: DateTime(2026, 10, day + 1, 2),
  hostName: '样例发起人',
  merchantHost: true,
  place: '样例活动地点',
  capacity: capacity,
  seatGenders: seatGenders,
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
      final cardSize = tester.getSize(
        find.byKey(const ValueKey('together-card-night')),
      );
      expect(cardSize.width / cardSize.height, closeTo(690 / 240, .01));
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
        MaterialApp(home: TogetherReviewPage(onBack: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.text('布局样例 · 非真实活动'), findsOneWidget);
      expect(find.text('一起玩'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('together-card-friends')));
      await tester.pumpAndSettle();
      expect(find.byType(TogetherPartyDetailPage), findsNothing);
      await tester.tap(find.byKey(const ValueKey('together-date-1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('together-card-friends')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('store selection filters city and resets table on store change', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
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
      repo.current = fixture(state: TogetherJoinState.full);
      await tester.tap(find.text('抢定'));
      await tester.pumpAndSettle();
      expect(joined, 0);
      expect(find.text('已满员'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
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
      expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      expect(find.text('抢定'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
