import 'package:kingclub/src/core/formatters/money.dart';

import 'dart:typed_data';

enum TogetherFeeMode { aa, menPay, hostTreat }

enum TogetherGender { male, female, unspecified }

enum TogetherJoinState {
  available,
  pendingPayment,
  joined,
  full,
  closed,
  cancelled,
}

class TogetherParticipant {
  const TogetherParticipant({
    required this.name,
    this.avatar,
    this.gender = TogetherGender.unspecified,
    this.seatIndex,
    this.avatarBytes,
    this.isMe = false,
  });
  final String name;
  final String? avatar;
  final TogetherGender gender;
  final int? seatIndex;
  final Uint8List? avatarBytes;
  final bool isMe;
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
    this.collaboratorHost = false,
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
    this.posterUrls = const [],
    this.storeLogo,
    this.assignedTable,
    this.ticketNumber,
    this.admissionCode,
    this.admissionExpiresAt,
    this.admissionUsed = false,
    this.allowCoins = false,
    this.seatGenders = const [],
    this.eligible,
    this.eligibilityReasons = const [],
    this.personalPriceMinor,
    this.confirmedCount,
    this.bookingStatus,
    this.bookingRef,
    this.bookingPayableMinor,
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
  final bool collaboratorHost;
  String get publisherLabel => merchantHost
      ? '商家'
      : collaboratorHost
      ? '合作者'
      : '会员';
  final int capacity, priceMinor;
  final List<TogetherParticipant> participants;
  final TogetherFeeMode feeMode;
  final TogetherJoinState state;
  final String? backgroundUrl, posterUrl;
  final List<String> posterUrls;

  /// Multi-poster activities take precedence over the original single image.
  List<String> get detailPosters => posterUrls.isNotEmpty
      ? posterUrls.take(3).toList(growable: false)
      : [if (posterUrl != null && posterUrl!.isNotEmpty) posterUrl!];

  /// Merchant-provided image reference; never assume every store is KING.
  final String? storeLogo;

  /// Server-assigned position. Signed collaborator positions are public before
  /// purchase; merchant blind positions are disclosed after confirmation only.
  final String? assignedTable;

  /// Authenticated member's credential projection; never derive from party ID.
  final String? ticketNumber, admissionCode;
  final bool admissionUsed, allowCoins;
  final DateTime? admissionExpiresAt;
  TogetherParty withAdmission({
    required String number,
    required String code,
    required DateTime expiresAt,
  }) => TogetherParty(
    ref: ref,
    theme: theme,
    cityCode: cityCode,
    cityName: cityName,
    storeRef: storeRef,
    storeName: storeName,
    startsAt: startsAt,
    endsAt: endsAt,
    hostName: hostName,
    merchantHost: merchantHost,
    collaboratorHost: collaboratorHost,
    place: place,
    capacity: capacity,
    participants: participants,
    feeMode: feeMode,
    priceMinor: priceMinor,
    state: state,
    description: description,
    rules: rules,
    backgroundUrl: backgroundUrl,
    posterUrl: posterUrl,
    posterUrls: posterUrls,
    storeLogo: storeLogo,
    assignedTable: assignedTable,
    ticketNumber: number,
    admissionCode: code,
    admissionExpiresAt: expiresAt,
    admissionUsed: admissionUsed,
    allowCoins: allowCoins,
    seatGenders: seatGenders,
    eligible: eligible,
    eligibilityReasons: eligibilityReasons,
    personalPriceMinor: personalPriceMinor,
    confirmedCount: confirmedCount,
    bookingStatus: bookingStatus,
    bookingRef: bookingRef,
    bookingPayableMinor: bookingPayableMinor,
  );

  /// Confirmed participation; pending payment is never an admission ticket.
  bool get hasAdmissionTicket => state == TogetherJoinState.joined;
  bool get hasAssignedTable =>
      hasAdmissionTicket &&
      assignedTable != null &&
      assignedTable!.trim().isNotEmpty;
  final List<TogetherGender> seatGenders;
  final bool? eligible;
  final List<String> eligibilityReasons;
  final int? personalPriceMinor;
  final int? confirmedCount;
  final String? bookingStatus;
  final String? bookingRef;
  final int? bookingPayableMinor;
  int get participantCount => confirmedCount ?? participants.length;

  int get remaining => (capacity - participantCount).clamp(0, capacity);
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
    return '¥${groupMoney(amount)}/${feeMode == TogetherFeeMode.menPay ? '男士' : '人'}';
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
  bool get canAct =>
      (eligible != false || hasAdmissionTicket) &&
      const {
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

abstract interface class TogetherAdmissionRepository {
  Future<TogetherParty> admission(String ref);
}

class TogetherRemovalMember {
  const TogetherRemovalMember(this.bookingRef, this.name, this.admitted);
  final String bookingRef, name;
  final bool admitted;
}

class TogetherRemovalMembers {
  const TogetherRemovalMembers(this.canManage, this.items, this.next);
  final bool canManage;
  final List<TogetherRemovalMember> items;
  final String? next;
}

class TogetherRemovalQuote {
  const TogetherRemovalQuote(
    this.bookingRef,
    this.refundMinor,
    this.participantCompensationMinor,
    this.merchantCompensationMinor,
    this.totalMinor,
    this.methods,
  );
  final String bookingRef;
  final int refundMinor,
      participantCompensationMinor,
      merchantCompensationMinor,
      totalMinor;
  final List<String> methods;
}

abstract interface class TogetherRemovalRepository {
  Future<TogetherRemovalMembers> removalMembers(
    String partyRef, {
    String? after,
  });
  Future<TogetherRemovalQuote> removalQuote(String partyRef, String bookingRef);
  Future<void> payRemoval(
    String partyRef,
    TogetherRemovalQuote quote, {
    required String requestRef,
    required String method,
  });
}
