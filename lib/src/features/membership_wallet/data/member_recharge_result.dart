/// A credited receipt proves this recharge, not the current spendable balance.
/// Reload the balance snapshot after success; never add these values locally.
class MemberRechargeResult {
  const MemberRechargeResult._(
    this.state,
    this.rechargeRef,
    this.storeRef,
    this.userAccount, {
    this.principalCents,
    this.giftCents,
    this.creditedAt,
  });
  final String state, rechargeRef, storeRef, userAccount;
  final int? principalCents, giftCents;
  final DateTime? creditedAt;
  bool get credited => state == 'credited';
  factory MemberRechargeResult.parse(
    Object? raw, {
    required String storeRef,
    required String rechargeRef,
    required String userAccount,
    required int principalCents,
    required int giftCents,
  }) {
    if (!_ref.hasMatch(storeRef) ||
        !_ref.hasMatch(userAccount) ||
        !_uuid.hasMatch(rechargeRef) ||
        principalCents < 1 ||
        principalCents > 100000000 ||
        giftCents < 0 ||
        giftCents > 100000000) {
      throw _invalid();
    }
    if (raw is! Map<String, dynamic>) throw _invalid();
    final state = raw['state'];
    if (![
          'not_sent',
          'pending',
          'unknown',
          'review_required',
          'credit_pending',
          'credited',
        ].contains(state) ||
        raw['rechargeRef'] != rechargeRef) {
      throw _invalid();
    }
    _keys(
      raw,
      state == 'credited'
          ? {'state', 'rechargeRef', 'receipt'}
          : {'state', 'rechargeRef'},
    );
    if (state != 'credited') {
      return MemberRechargeResult._(
        state as String,
        rechargeRef,
        storeRef,
        userAccount,
      );
    }
    final receipt = raw['receipt'];
    if (receipt is! Map<String, dynamic>) throw _invalid();
    _keys(receipt, {
      'version',
      'rechargeRef',
      'storeRef',
      'userAccount',
      'currency',
      'accountType',
      'lotRef',
      'principalCents',
      'giftCents',
      'creditedAt',
    });
    final lot = receipt['lotRef'], timestamp = receipt['creditedAt'];
    if (receipt['version'] != 1 ||
        receipt['rechargeRef'] != rechargeRef ||
        receipt['storeRef'] != storeRef ||
        receipt['userAccount'] != userAccount ||
        receipt['currency'] != 'CNY' ||
        receipt['accountType'] != 'store_balance' ||
        lot is! String ||
        !_uuid.hasMatch(lot) ||
        receipt['principalCents'] != principalCents.toString() ||
        receipt['giftCents'] != giftCents.toString() ||
        timestamp is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$')
            .hasMatch(timestamp)) {
      throw _invalid();
    }
    final at = DateTime.tryParse(timestamp);
    if (at == null || at.toIso8601String() != timestamp) throw _invalid();
    return MemberRechargeResult._(
      'credited',
      rechargeRef,
      storeRef,
      userAccount,
      principalCents: principalCents,
      giftCents: giftCents,
      creditedAt: at,
    );
  }
}

final _ref = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _uuid = RegExp(
  r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
);
FormatException _invalid() =>
    const FormatException('Invalid recharge query result');
void _keys(Map<String, dynamic> value, Set<String> keys) {
  if (value.length != keys.length || !value.keys.every(keys.contains)) {
    throw _invalid();
  }
}
