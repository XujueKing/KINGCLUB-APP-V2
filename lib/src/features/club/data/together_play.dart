enum TogetherFeeMode { aa, menPay, hostTreat }

enum TogetherJoinState {
  available,
  pendingPayment,
  joined,
  full,
  closed,
  cancelled,
}

class TogetherParticipant {
  const TogetherParticipant({required this.name, this.avatar});
  final String name;
  final String? avatar;
}

/// Read projection. Prices, membership state and capacity come from the service.
class TogetherParty {
  const TogetherParty({
    required this.ref,
    required this.theme,
    required this.cityCode,
    required this.cityName,
    required this.storeRef,
    required this.storeName,
    required this.startsAt,
    required this.endsAt,
    required this.hostName,
    required this.merchantHost,
    required this.place,
    required this.capacity,
    required this.participants,
    required this.feeMode,
    required this.priceMinor,
    required this.state,
    required this.description,
    required this.rules,
    this.backgroundUrl,
    this.posterUrl,
  });
  final String ref,
      theme,
      cityCode,
      cityName,
      storeRef,
      storeName,
      hostName,
      place,
      description,
      rules;
  final DateTime startsAt, endsAt;
  final bool merchantHost;
  final int capacity, priceMinor;
  final List<TogetherParticipant> participants;
  final TogetherFeeMode feeMode;
  final TogetherJoinState state;
  final String? backgroundUrl, posterUrl;

  int get remaining => (capacity - participants.length).clamp(0, capacity);
  String get feeLabel => switch (feeMode) {
    TogetherFeeMode.aa => 'AA 制',
    TogetherFeeMode.menPay => '男 A 女免',
    TogetherFeeMode.hostTreat => '发起者请客 · 全免',
  };
  String get priceLabel {
    if (feeMode == TogetherFeeMode.hostTreat) return '免费参加';
    final whole = priceMinor ~/ 100;
    final cents = priceMinor % 100;
    final amount = cents == 0
        ? '$whole'
        : '$whole.${cents.toString().padLeft(2, '0')}';
    return '¥$amount/${feeMode == TogetherFeeMode.menPay ? '男士' : '人'}';
  }

  TogetherJoinState get actionState =>
      state == TogetherJoinState.available && remaining == 0
      ? TogetherJoinState.full
      : state;
  String get actionLabel => switch (actionState) {
    TogetherJoinState.available => '抢定',
    TogetherJoinState.pendingPayment => '继续支付',
    TogetherJoinState.joined => '入场码',
    TogetherJoinState.full => '已满员',
    TogetherJoinState.closed => '已截止',
    TogetherJoinState.cancelled => '已取消',
  };
  bool get canAct => const {
    TogetherJoinState.available,
    TogetherJoinState.pendingPayment,
    TogetherJoinState.joined,
  }.contains(actionState);
}

abstract interface class TogetherPlayRepository {
  Future<List<TogetherParty>> list({
    required String cityCode,
    required DateTime date,
  });
  Future<TogetherParty> detail(String ref);
}
