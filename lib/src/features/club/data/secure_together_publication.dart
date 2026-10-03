import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../../commerce/data/ordering_table_repository.dart';
import 'together_party_draft.dart';
import 'together_play.dart';

class TogetherPublicationQuote {
  const TogetherPublicationQuote({
    required this.ref,
    required this.depositCents,
    required this.priceCents,
    required this.expiresAt,
    required this.policyVersion,
    required this.sessionIdentity,
  });
  final String ref, depositCents, priceCents, policyVersion;
  final DateTime expiresAt;
  final String sessionIdentity;
}

/// Uses the existing quote and atomic deposit/publication interfaces.
/// Callers retain requestRef when retrying an unknown result.
class SecureTogetherPublication {
  SecureTogetherPublication({required this.readSession, required this.request});
  factory SecureTogetherPublication.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final sessions = SecureSessionStore();
    return SecureTogetherPublication(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;

  String _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final values = [
      if (account is Map) account['userAccount'],
      session?['sessionId'],
      session?['apiKeyId'],
    ];
    if (values.length != 3 ||
        values.any((v) => v is! String || v.isEmpty) ||
        session?['apiKey'] is! String ||
        (session!['apiKey'] as String).isEmpty) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    return values.join('\u0000');
  }

  Never _invalid() =>
      throw const AuthFailure('TOGETHER_RESPONSE_INVALID', '活动信息暂不可用');
  String _ref(dynamic value) {
    if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(value)) {
      _invalid();
    }
    return value;
  }

  String _money(dynamic value) {
    if (value is! String || !RegExp(r'^(0|[1-9][0-9]{0,17})$').hasMatch(value)) {
      _invalid();
    }
    return value;
  }

  Future<Map> _call(
    String id,
    Map<String, dynamic> params,
    Map<String, dynamic> session,
    String identity,
  ) async {
    final response = await request(id, params, session);
    if (_identity(await readSession()) != identity) {
      throw const AuthFailure('SESSION_EXPIRED', '登录状态已变化');
    }
    final result = response['result'];
    if (result is! Map) _invalid();
    return result;
  }

  Future<TogetherPublicationQuote> quote(
    TogetherPartyDraft draft, {
    required String requestRef,
  }) async {
    _ref(requestRef);
    final error = draft.validate(now: DateTime.now());
    if (error != null) throw AuthFailure('TOGETHER_DRAFT_INVALID', error);
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261002001984',
      {
        'draft': {
          'requestRef': requestRef,
          'cityCode': draft.cityCode,
          'storeRef': draft.storeRef,
          'tableRef': draft.tableRef,
          'theme': draft.theme,
          'place': draft.place,
          'description': draft.description,
          'startsAt': draft.startsAt.toUtc().toIso8601String(),
          'endsAt': draft.endsAt.toUtc().toIso8601String(),
          'capacity': draft.capacity,
          'feeMode': switch (draft.feeMode) {
            TogetherFeeMode.aa => 'aa',
            TogetherFeeMode.menPay => 'men_pay',
            TogetherFeeMode.hostTreat => 'host_treat',
          },
          'priceCents': '${draft.priceMinor}',
          'totalCents': '${draft.totalCostMinor}',
          'backgroundRef': draft.background.ref,
          'posterRef': draft.poster.ref,
          'posterRefs': draft.posters.map((p) => p.ref).toList(),
        },
      },
      session!,
      identity,
    );
    final expiresAt = DateTime.tryParse('${result['expiresAt']}');
    final policy = result['policyVersion'];
    if (expiresAt == null ||
        !expiresAt.isAfter(DateTime.now()) ||
        policy is! String ||
        policy.isEmpty) {
      _invalid();
    }
    return TogetherPublicationQuote(
      ref: _ref(result['quoteRef']),
      depositCents: _money(result['totalCents']),
      priceCents: _money(result['priceCents']),
      expiresAt: expiresAt,
      policyVersion: policy,
      sessionIdentity: identity,
    );
  }

  Future<String> publish(
    TogetherPublicationQuote quote, {
    required String requestRef,
  }) async {
    _ref(requestRef);
    final session = await readSession();
    final identity = _identity(session);
    if (identity != quote.sessionIdentity) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新确认活动报价');
    }
    // Even an expired quote may be a retry of a successful publication.
    // The server distinguishes replay from a new expired request atomically.
    final result = await _call(
      'K261002001982',
      {'quoteRef': quote.ref, 'requestRef': requestRef},
      session!,
      identity,
    );
    if (_money(result['frozenCents']) != quote.depositCents) _invalid();
    return _ref(result['partyRef']);
  }
}
