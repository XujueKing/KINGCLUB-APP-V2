import 'package:flutter/material.dart';

import '../data/together_play.dart';
import 'together_play_page.dart';
import '../../../core/design_system/king_notice.dart';

/// Explicit, non-transactional layout review requested before later pages.
/// No member records, payments or attendance state are created by this page.
class TogetherReviewPage extends StatelessWidget {
  const TogetherReviewPage({super.key, required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => TogetherPlayPage(
    repository: _LayoutExamples(DateUtils.dateOnly(DateTime.now())),
    cityCode: 'review',
    cityName: '同城一起玩',
    onBack: onBack,
    reviewOnly: true,
    onCreate: () => KingNotice.of(context).show('本轮先验收列表页，发起组局稍后接入'),
    onJoin: (_) async {},
    onAdmission: (_) async {},
  );
}

class _LayoutExamples implements TogetherPlayRepository {
  const _LayoutExamples(this.ticketDate);
  final DateTime ticketDate;
  @override
  Future<List<TogetherParty>> list({
    required String cityCode,
    required DateTime date,
  }) async => [
    if (DateUtils.isSameDay(date, ticketDate))
      _card(
        date,
        'friends',
        '卡颜AA交友局',
        TogetherFeeMode.aa,
        TogetherJoinState.joined,
        10,
        1,
        38800,
      ),
    _card(
      date,
      'music',
      '一起听歌 · 轻松认识',
      TogetherFeeMode.menPay,
      TogetherJoinState.available,
      10,
      4,
      19800,
    ),
    _card(
      date,
      'birthday',
      '生日快乐 · 今晚我请客',
      TogetherFeeMode.hostTreat,
      TogetherJoinState.available,
      8,
      3,
      0,
    ),
  ];
  TogetherParty _card(
    DateTime date,
    String ref,
    String theme,
    TogetherFeeMode mode,
    TogetherJoinState state,
    int capacity,
    int count,
    int price,
  ) => TogetherParty(
    ref: ref,
    theme: theme,
    cityCode: 'review',
    cityName: '当前城市',
    storeRef: 'review-store',
    storeName: 'KINGCLUB湖南工大店',
    storeLogo: 'assets/legacy/aa/kingclub-store.png',
    assignedTable: state == TogetherJoinState.joined ? '888' : null,
    ticketNumber: state == TogetherJoinState.joined
        ? 'KC${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}0001'
        : null,
    // Reserved preview namespace, intentionally not a legacy redeemable URL.
    admissionCode: state == TogetherJoinState.joined
        ? 'KINGCLUB-LAYOUT-PREVIEW:$ref:${date.toIso8601String()}'
        : null,
    startsAt: DateTime(date.year, date.month, date.day, 21),
    endsAt: DateTime(date.year, date.month, date.day + 1, 2),
    hostName: ref == 'music' ? 'KINGCLUB官方' : '会员发起人',
    merchantHost: ref == 'music',
    place: '门店地址展示位',
    capacity: capacity,
    participants: List.generate(
      count,
      (i) => TogetherParticipant(
        name: '头像占位 ${i + 1}',
        seatIndex: i.isEven ? i ~/ 2 : (capacity + 1) ~/ 2 + i ~/ 2,
        gender: i.isEven ? TogetherGender.male : TogetherGender.female,
      ),
    ),
    seatGenders: List.generate(
      capacity,
      (i) =>
          i < (capacity + 1) ~/ 2 ? TogetherGender.male : TogetherGender.female,
    ),
    feeMode: mode,
    priceMinor: price,
    state: state,
    description: '',
    rules: switch (mode) {
      TogetherFeeMode.aa => '费用AA；请按时到场，文明交流。',
      TogetherFeeMode.menPay => '男士AA，女士免票；请按时到场，文明交流。',
      TogetherFeeMode.hostTreat => '发起者请客，参加免费；请衣着整洁，尊重同桌。',
    },
  );
  @override
  Future<TogetherParty> detail(String ref) =>
      throw StateError('Layout review has no business detail');
}
