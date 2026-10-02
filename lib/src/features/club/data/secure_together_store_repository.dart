import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../../commerce/data/ordering_table_repository.dart';
import 'together_store.dart';

Never _invalid() =>
    throw const AuthFailure('STORE_DIRECTORY_INVALID', '门店信息暂不可用');
String _text(dynamic value, int max) {
  if (value is! String || value.isEmpty || value.length > max) _invalid();
  return value;
}

String _ref(dynamic value) {
  final text = _text(value, 64);
  if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(text)) _invalid();
  return text;
}

class SecureTogetherStoreRepository implements TogetherStoreRepository {
  SecureTogetherStoreRepository({
    required this.readSession,
    required this.request,
  });
  factory SecureTogetherStoreRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final sessions = SecureSessionStore();
    return SecureTogetherStoreRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  String? _identity(Map<String, dynamic>? session) {
    if (session?['account'] is! Map) return null;
    final parts = [
      (session!['account'] as Map)['userAccount'],
      session['sessionId'],
      session['apiKeyId'],
      session['apiKey'],
    ];
    if (parts.any((v) => v is! String || v.isEmpty)) return null;
    return parts.join('\u0000');
  }

  Future<List<Map>> _pages(
    String id,
    String scope,
    String value,
    String refKey,
  ) async {
    _ref(value);
    final session = await readSession();
    final identity = _identity(session);
    if (identity == null) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    final items = <Map>[];
    final seen = <String>{};
    String? after;
    do {
      final response = await request(id, {
        scope: value,
        'limit': 100,
        'after': ?after,
      }, session!);
      if (_identity(await readSession()) != identity) {
        throw const AuthFailure('SESSION_EXPIRED', '登录状态已变化');
      }
      final result = response['result'];
      if (result is! Map || result[scope] != value || result['items'] is! List) {
        _invalid();
      }
      final page = result['items'] as List;
      if (page.length > 100) _invalid();
      for (final item in page) {
        if (item is! Map || item[scope] != value) _invalid();
        final ref = _ref(item[refKey]);
        if (!seen.add(ref)) _invalid();
        items.add(item);
      }
      final next = result['next'];
      if (next != null &&
          (page.isEmpty || _ref(next) != page.last[refKey] || next == after)) {
        _invalid();
      }
      after = next as String?;
    } while (after != null);
    return items;
  }

  @override
  Future<List<TogetherStore>> list({required String cityCode}) async =>
      (await _pages('K261002001980', 'cityCode', cityCode, 'storeRef')).map((
        r,
      ) {
        final address = r['address'];
        if (address is! String || address.length > 300) _invalid();
        return TogetherStore(
          ref: _ref(r['storeRef']),
          name: _text(r['name'], 128),
          cityCode: _ref(r['cityCode']),
          address: address,
        );
      }).toList();

  @override
  Future<List<TogetherTable>> tables({required String storeRef}) async =>
      (await _pages('K261002001981', 'storeRef', storeRef, 'tableRef')).map((
        r,
      ) {
        final seats = r['maximumSeats'];
        if (seats is! int || seats < 2 || seats > 65535) _invalid();
        return TogetherTable(
          ref: _ref(r['tableRef']),
          storeRef: _ref(r['storeRef']),
          name: _text(r['name'], 64),
          maximumSeats: seats,
        );
      }).toList();
}
