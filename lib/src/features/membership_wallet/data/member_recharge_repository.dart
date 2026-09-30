import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'member_recharge_catalog.dart';
import 'member_recharge_result.dart';

typedef RechargeCall = Future<Map<String, dynamic>> Function(
  String id,
  Map<String, dynamic> params,
);

/// No automatic retries: callers must retain the same requestId for recovery.
/// Creating an original order neither takes payment nor credits a balance.
class MemberRechargeRepository {
  MemberRechargeRepository({this.call, int Function()? generation})
    : _generation = generation ?? (() => MemberQrMemory.generation);
  final RechargeCall? call;
  final int Function() _generation;
  Future<Map<String, dynamic>> _invoke(
    String id,
    Map<String, dynamic> params, {
    String? expectedUserAccount,
  }) async {
    final epoch = _generation();
    void check() {
      if (epoch != _generation()) throw StateError('RECHARGE_SESSION_CHANGED');
    }

    final Map<String, dynamic> result;
    if (call != null) {
      result = await call!(id, params);
    } else {
      final session = await SecureSessionStore().readSession();
      check();
      if (session == null) throw StateError('RECHARGE_SESSION_REQUIRED');
      if (expectedUserAccount != null &&
          (session['account'] as Map?)?['userAccount'] != expectedUserAccount) {
        throw StateError('RECHARGE_SESSION_CHANGED');
      }
      final envelope = await KingclubSecureClient(kingclubApiBaseUrl)
          .call(id, params, session: session);
      check();
      if (envelope['result'] is! Map) {
        throw const FormatException('Invalid recharge result');
      }
      result = Map<String, dynamic>.from(envelope['result'] as Map);
    }
    check();
    return result;
  }

  Future<MemberRechargeCatalog> catalog(String storeRef) async {
    _checkRef(storeRef);
    return MemberRechargeCatalog.parse(
      await _invoke('K260930000512', {'storeRef': storeRef}),
      storeRef: storeRef,
    );
  }

  /// Server reconciliation may finish an already-paid credit. No new payment
  /// is sent, and no member identity or expected amount is accepted by the API.
  Future<MemberRechargeResult> query(
    MemberRechargeOriginal original, {
    required String userAccount,
  }) async {
    _checkRef(userAccount);
    final result = await _invoke('K260930000511', {
      'storeRef': original.storeRef,
      'rechargeRef': original.rechargeRef,
    }, expectedUserAccount: userAccount);
    return MemberRechargeResult.parse(
      result,
      storeRef: original.storeRef,
      rechargeRef: original.rechargeRef,
      userAccount: userAccount,
      principalCents: original.principalCents,
      giftCents: original.giftCents,
    );
  }

  Future<MemberRechargeOriginal> prepare({
    required String requestId,
    required String storeRef,
    required String campaignRef,
    required int campaignRevision,
    required String channel,
    String? expectedUserAccount,
  }) async {
    _checkRef(storeRef);
    _checkRef(campaignRef);
    if (!_uuid.hasMatch(requestId) ||
        campaignRevision < 1 ||
        campaignRevision > 9007199254740991 ||
        !['wechat', 'alipay'].contains(channel)) {
      throw const FormatException('Invalid recharge selection');
    }
    final result = await _invoke('K260930000510', {
      'requestId': requestId,
      'storeRef': storeRef,
      'campaignRef': campaignRef,
      'campaignRevision': campaignRevision,
      'channel': channel,
    }, expectedUserAccount: expectedUserAccount);
    return MemberRechargeOriginal.parse(
      result,
      storeRef: storeRef,
      channel: channel,
    );
  }
}

final _uuid = RegExp(
  r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
);
void _checkRef(String ref) {
  if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(ref)) {
    throw const FormatException('Invalid recharge scope');
  }
}

class MemberRechargeOriginal {
  const MemberRechargeOriginal._(
    this.rechargeRef,
    this.storeRef,
    this.channel,
    this.principalCents,
    this.giftCents,
    this.paymentStatus,
    this.creditStatus,
  );
  final String rechargeRef, storeRef, channel, paymentStatus, creditStatus;
  final int principalCents, giftCents;
  factory MemberRechargeOriginal.parse(
    Map<String, dynamic> raw, {
    required String storeRef,
    required String channel,
  }) {
    const keys = {
      'rechargeRef',
      'storeRef',
      'channel',
      'principalCents',
      'giftCents',
      'paymentStatus',
      'creditStatus',
    };
    final ref = raw['rechargeRef'],
        payment = raw['paymentStatus'],
        credit = raw['creditStatus'];
    if (raw.length != keys.length ||
        !raw.keys.every(keys.contains) ||
        ref is! String ||
        !_uuid.hasMatch(ref) ||
        raw['storeRef'] != storeRef ||
        raw['channel'] != channel ||
        !['wechat', 'alipay'].contains(channel) ||
        ![
          'prepared',
          'pending',
          'unknown',
          'confirmed',
          'closed',
        ].contains(payment) ||
        !['awaiting_payment', 'pending', 'credited'].contains(credit) ||
        ((payment == 'confirmed') == (credit == 'awaiting_payment'))) {
      throw const FormatException('Invalid recharge original');
    }
    int cents(Object? value) {
      if (value is! String ||
          !RegExp(r'^(0|[1-9][0-9]{0,8})$').hasMatch(value)) {
        throw const FormatException('Invalid recharge amount');
      }
      final n = int.parse(value);
      if (n > 100000000) throw const FormatException('Invalid recharge amount');
      return n;
    }

    final principal = cents(raw['principalCents']);
    if (principal == 0) {
      throw const FormatException('Invalid recharge principal');
    }
    return MemberRechargeOriginal._(
      ref,
      storeRef,
      channel,
      principal,
      cents(raw['giftCents']),
      payment as String,
      credit as String,
    );
  }
}
