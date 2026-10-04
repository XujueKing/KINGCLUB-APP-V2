import 'dart:convert';
import 'dart:typed_data';

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
    this.malePriceCents,
    this.femalePriceCents,
  });
  final String ref, depositCents, priceCents, policyVersion;
  final DateTime expiresAt;
  final String sessionIdentity;
  final String? malePriceCents, femalePriceCents;
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
    if (value is! String ||
        !RegExp(r'^(0|[1-9][0-9]{0,17})$').hasMatch(value)) {
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

  Map<int, String> _memberLevels = {};
  Map<int, String> get memberLevels => Map.unmodifiable(_memberLevels);

  Future<List<TogetherPackage>> packages(String storeRef) async {
    _ref(storeRef);
    final levels = <int, String>{};
    final session = await readSession();
    final identity = _identity(session);
    final items = <TogetherPackage>[];
    final seen = <String>{};
    String? after;
    do {
      final result = await _call(
        'K261004001987',
        {'storeRef': storeRef, 'after': ?after},
        session!,
        identity,
      );
      if (result['storeRef'] != storeRef || result['items'] is! List) {
        _invalid();
      }
      final options = result['memberLevels'];
      if (options != null) {
        if (options is! List || options.length > 100) _invalid();
        for (final option in options) {
          if (option is! Map ||
              option['name'] is! String ||
              (option['name'] as String).isEmpty ||
              option['minimumExperience'] is! int ||
              (option['minimumExperience'] as int) < 0 ||
              (option['minimumExperience'] as int) > 1000000000) {
            _invalid();
          }
          levels[option['minimumExperience'] as int] = option['name'] as String;
        }
      }
      final page = result['items'] as List;
      if (page.length > 100) _invalid();
      for (final row in page) {
        if (row is! Map || row['names'] is! Map) _invalid();
        final name = row['names']['zh-CN'];
        final ref = _ref(row['ref']);
        final amount = int.tryParse(_money(row['baseTotalCents']));
        if (name is! String ||
            name.isEmpty ||
            amount == null ||
            amount < 1 ||
            amount > 100000000 ||
            !seen.add(ref)) {
          _invalid();
        }
        items.add(
          TogetherPackage(
            ref: ref,
            storeRef: storeRef,
            name: name,
            baseTotalMinor: amount,
          ),
        );
      }
      final next = result['next'];
      if (next != null &&
          (page.isEmpty || _ref(next) != items.last.ref || next == after)) {
        _invalid();
      }
      after = next as String?;
    } while (after != null);
    _memberLevels = levels;
    return items;
  }

  Future<String> submitArtwork({
    required String requestRef,
    required String name,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 800000) {
      throw const AuthFailure('TOGETHER_IMAGE_SIZE', '图片须小于800KB');
    }
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001994',
      {
        'action': 'submit',
        'requestRef': requestRef,
        'name': name,
        'base64': base64Encode(bytes),
      },
      session!,
      identity,
    );
    _ref(result['ref']);
    final status = result['status'];
    if (!['pending', 'approved', 'rejected', 'revoked'].contains(status) ||
        result['replayed'] is! bool) {
      _invalid();
    }
    return status as String;
  }

  Future<List<Map<String, String>>> myArtwork() async {
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001994',
      {'action': 'mine'},
      session!,
      identity,
    );
    final rows = result['items'];
    if (rows is! List || rows.length > 100) _invalid();
    return rows.map((row) {
      if (row is! Map ||
          row['name'] is! String ||
          ![
            'pending',
            'approved',
            'rejected',
            'revoked',
          ].contains(row['status']) ||
          (row['reason'] != null && row['reason'] is! String)) {
        _invalid();
      }
      return <String, String>{
        'ref': _ref(row['ref']),
        'name': row['name'] as String,
        'status': row['status'] as String,
        'reason': row['reason'] as String? ?? '',
      };
    }).toList();
  }

  Future<List<TogetherArtwork>> artwork() async {
    final session = await readSession();
    final identity = _identity(session);
    final items = <TogetherArtwork>[];
    final seen = <String>{};
    String? after;
    do {
      final result = await _call(
        'K261002001983',
        {'after': ?after},
        session!,
        identity,
      );
      final page = result['items'];
      if (page is! List || page.length > 100) _invalid();
      for (final row in page) {
        if (row is! Map || row['status'] != 'approved') _invalid();
        final ref = _ref(row['ref']);
        final name = row['name'];
        final url = row['url'];
        if (!seen.add(ref) ||
            name is! String ||
            name.length > 128 ||
            url is! String ||
            url.length > 2048) {
          _invalid();
        }
        final uri = Uri.tryParse(url);
        if (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty ||
            uri.queryParameters.keys.any(
              (key) => RegExp(
                r'token|signature|credential|secret|authorization',
                caseSensitive: false,
              ).hasMatch(key),
            )) {
          _invalid();
        }
        items.add(
          TogetherArtwork(
            ref: ref,
            name: name,
            url: url,
            status: TogetherArtworkStatus.approved,
          ),
        );
      }
      final next = result['next'];
      if (next != null &&
          (page.isEmpty || _ref(next) != page.last['ref'] || next == after)) {
        _invalid();
      }
      after = next as String?;
    } while (after != null);
    return items;
  }

  Future<TogetherPublicationQuote> quote(
    TogetherPartyDraft draft, {
    required String requestRef,
  }) async {
    _ref(requestRef);
    if (draft.package == null) {
      throw const AuthFailure('TOGETHER_PACKAGE_REQUIRED', '请选择门店组局套餐');
    }
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
          'allowCoins': draft.allowCoins,
          'publisherType': draft.official ? 'official' : 'personal',
          'storeRef': draft.storeRef,
          'packageRef': draft.package!.ref,
          if (draft.eligibilityRules.isNotEmpty)
            'eligibilityRules': draft.eligibilityRules,
          if (draft.maleSeats != null)
            'genderPricing': {
              'maleSeats': draft.maleSeats,
              'femaleSeats': draft.femaleSeats,
              'femaleBasePriceCents': '${draft.femaleBasePriceMinor}',
            },
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
    final deposit = _money(
      result['depositCents'] ?? (draft.official ? null : result['totalCents']),
    );
    if (_money(result['totalCents']) != '${draft.totalCostMinor}' ||
        deposit != (draft.official ? '0' : '${draft.totalCostMinor}')) {
      _invalid();
    }
    return TogetherPublicationQuote(
      ref: _ref(result['quoteRef']),
      depositCents: deposit,
      priceCents: _money(result['priceCents']),
      expiresAt: expiresAt,
      policyVersion: policy,
      sessionIdentity: identity,
      malePriceCents: result['genderPricing'] is Map
          ? _money(result['genderPricing']['malePriceCents'])
          : null,
      femalePriceCents: result['genderPricing'] is Map
          ? _money(result['genderPricing']['femalePriceCents'])
          : null,
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
