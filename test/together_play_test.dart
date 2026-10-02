import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/data/together_party_draft.dart';
import 'package:kingclub/src/features/club/presentation/together_play_page.dart';

TogetherParty fixture({
  String ref = 'night',
  String city = '430200',
  TogetherFeeMode fee = TogetherFeeMode.aa,
  TogetherJoinState state = TogetherJoinState.available,
  int capacity = 10,
  int count = 3,
  int day = 2,
}) => TogetherParty(
  ref: ref,
  theme: ref == 'night' ? '周末微醺交友局' : '一起听歌 · 认识新朋友',
  cityCode: city,
  cityName: '株洲市',
  startsAt: DateTime(2026, 10, day, 21),
  endsAt: DateTime(2026, 10, day + 1, 2),
  hostName: '样例发起人',
  merchantHost: true,
  place: '样例活动地点',
  capacity: capacity,
  participants: List.generate(
    count,
    (i) => TogetherParticipant(name: '样例会员$i'),
  ),
  feeMode: fee,
  priceMinor: 38850,
  state: state,
  description: '一起听音乐、认识新朋友。活动内容以本场说明为准。',
  rules: '报名与取消规则将在确认报名时展示。',
);

class Repository implements TogetherPlayRepository {
  final requests = <Completer<List<TogetherParty>>>[];
  TogetherParty current = fixture();
  @override
  Future<List<TogetherParty>> list({
    required String cityCode,
    required DateTime date,
  }) {
    final request = Completer<List<TogetherParty>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<TogetherParty> detail(String ref) async => current;
}

void main() {
  test('creation blocks capacity overflow and unreviewed artwork; money stays integer cents', () {
    TogetherPartyDraft draft(TogetherArtworkStatus status) {
      final artwork = TogetherArtwork(
        ref: 'fixture',
        name: 'Test',
        url: 'https://example.test/image.webp',
        status: status,
      );
      return TogetherPartyDraft(
        theme: '聚会',
        cityCode: '430200',
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
        tableRef: 'fixture-table',
      );
    }

    final now = DateTime(2026, 10, 2);
    expect(
      draft(TogetherArtworkStatus.approved)
          .validate(now: now, maximumTableSeats: 8),
      '总人数不能超过桌台容量',
    );
    expect(
      draft(TogetherArtworkStatus.pending)
          .validate(now: now, maximumTableSeats: 10),
      '背景和海报审核通过后才能发布',
    );
    expect(
      draft(TogetherArtworkStatus.approved)
          .validate(now: now, maximumTableSeats: 10),
      isNull,
    );
    expect(TogetherPartyDraft.parseMoney('388.50'), 38850);
    expect(TogetherPartyDraft.parseMoney('0.01'), 1);
    expect(TogetherPartyDraft.parseMoney('1.001'), isNull);
    expect(TogetherPartyDraft.parseMoney('-1'), isNull);
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
