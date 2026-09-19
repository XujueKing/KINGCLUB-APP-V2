import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import 'ordering_context.dart';
import 'ordering_table_repository.dart';

class TableParty {
  const TableParty(this.revision, this.count, this.canEdit);
  final int revision;
  final int? count;
  final bool canEdit;
}

class TableManagementRepository {
  TableManagementRepository({required this.readSession, required this.request});
  factory TableManagementRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final store = SecureSessionStore();
    return TableManagementRepository(
      readSession: store.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  Future<Map<String, dynamic>> managedTables({String? after}) async {
    final result = await _call('K260920000820', {'afterTable': ?after});
    final rows = result['tables'];
    if (rows is! List || rows.length > 100) _invalid();
    for (final row in rows) {
      if (row is! Map) _invalid();
      for (final key in [
        'tableId',
        'tableName',
        'storeRef',
        'storeName',
        'cityName',
        'tableStatus',
        'storeStatus',
        'businessDate',
      ]) {
        if (row[key] is! String) _invalid();
      }
      final date = row['businessDate'] as String,
          parsed = DateTime.tryParse(row['businessDate'] as String);
      if (parsed == null ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          parsed.toIso8601String().substring(0, 10) != date ||
          row['maximumSeats'] is! int) {
        _invalid();
      }
    }
    final next = result['nextAfterTable'];
    if (next != null &&
        (next is! String ||
            rows.isEmpty ||
            next != rows.last['tableId'] ||
            next == after)) {
      _invalid();
    }
    return result;
  }

  List<String>? _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final values = [
      session?['sessionId'],
      session?['apiKeyId'],
      session?['apiKey'],
      account is Map ? account['userAccount'] : null,
    ];
    if (values.any((v) => v is! String || v.isEmpty)) return null;
    return values.cast<String>().toList();
  }

  Future<Map<String, dynamic>> _call(
    String id,
    Map<String, dynamic> params, {
    String? member,
  }) async {
    final session = await readSession(),
        before = _identity(await readSession());
    final sent = _identity(session);
    if (session == null ||
        before == null ||
        sent == null ||
        before.join('\u0000') != sent.join('\u0000') ||
        (member != null && before.last != member)) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    final response = await request(id, params, session);
    final after = _identity(await readSession());
    if (after == null || before.join('\u0000') != after.join('\u0000')) {
      throw const AuthFailure('SESSION_CHANGED', '请重新登录');
    }
    final result = response['result'];
    if (result is! Map) _invalid();
    return Map<String, dynamic>.from(result);
  }

  Never _invalid() =>
      throw const AuthFailure('TABLE_RESPONSE_INVALID', '桌台信息异常');
  Map<String, dynamic> _scope(OrderingContext scope) => {
    'tableId': scope.tableId,
    'storeRef': scope.storeRef,
    'sessionRef': scope.tableSessionRef,
  };
  TableParty _party(
    Map<String, dynamic> result,
    OrderingContext scope, {
    int? savedCount,
  }) {
    if (_scope(scope).entries.any((e) => result[e.key] != e.value)) _invalid();
    final revision = result['revision'], count = result['partySize'];
    if (revision is! int ||
        revision < 0 ||
        revision > 4294967295 ||
        (count != null && (count is! int || count < 1 || count > 65535)) ||
        result['requiredCups'] != count ||
        (savedCount != null && savedCount != count) ||
        (savedCount == null && result['canEdit'] is! bool)) {
      _invalid();
    }
    return TableParty(
      revision,
      count as int?,
      savedCount == null ? result['canEdit'] as bool : true,
    );
  }

  Future<TableParty> readParty(OrderingContext scope) async => _party(
    await _call('K260920000818', _scope(scope), member: scope.memberRef),
    scope,
  );
  Future<TableParty> saveParty(
    OrderingContext scope,
    int count,
    int revision,
    String requestId,
  ) async {
    if (count < 1 || count > 65535) _invalid();
    final result = _party(
      await _call('K260920000819', {
        ..._scope(scope),
        'partySize': count,
        'expectedRevision': revision,
        'requestId': requestId,
      }, member: scope.memberRef),
      scope,
      savedCount: count,
    );
    if (result.revision != revision + 1) _invalid();
    return result;
  }

  Future<Map<String, dynamic>> history(
    String table,
    String store,
    String date, {
    int? before,
  }) async {
    final result = await _call('K260920000817', {
      'tableId': table,
      'storeRef': store,
      'businessDate': date,
      'beforeRevision': ?before,
    });
    if (result['tableId'] != table ||
        result['storeRef'] != store ||
        result['businessDate'] != date ||
        result['entries'] is! List) {
      _invalid();
    }
    final rows = result['entries'] as List;
    if (rows.length > 100) _invalid();
    var previous = before ?? 4294967296;
    for (final row in rows) {
      if (row is! Map) _invalid();
      final revision = row['revision'], rule = row['rule'];
      if (revision is! int ||
          revision < 1 ||
          revision >= previous ||
          row['createdDate'] is! String ||
          row['operatedBy'] is! String ||
          rule is! Map) {
        _invalid();
      }
      previous = revision;
      final mode = rule['mode'];
      if (!['manual', 'minimum_people', 'minimum_spend', 'aa'].contains(mode)) {
        _invalid();
      }
      final value = mode == 'minimum_people'
          ? rule['minimumPeople']
          : rule['minimumSpendCents'];
      if ((mode == 'minimum_people' || mode == 'minimum_spend') &&
          (value is! int ||
              value < 1 ||
              value > (mode == 'minimum_people' ? 65535 : 2147483647))) {
        _invalid();
      }
    }
    final next = result['nextBeforeRevision'];
    if (next != null && (next is! int || rows.isEmpty || next != previous)) {
      _invalid();
    }
    return result;
  }

  Future<void> saveRule(
    String table,
    String store,
    String date,
    int revision,
    String requestId,
    Map<String, dynamic> rule,
  ) async {
    final result = await _call('K260920000816', {
      'tableId': table,
      'storeRef': store,
      'businessDate': date,
      'expectedRevision': revision,
      'requestId': requestId,
      'rule': rule,
    });
    if (result['businessDate'] != date ||
        result['revision'] != revision + 1 ||
        result['rule'] is! Map ||
        rule.entries.any((e) => (result['rule'] as Map)[e.key] != e.value)) {
      _invalid();
    }
  }
}
