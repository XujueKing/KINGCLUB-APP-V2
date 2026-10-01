import 'package:flutter/foundation.dart';

import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../../commerce/data/ordering_table_repository.dart';

const systemNoticeKinds = {
  'purchase_paid',
  'refund_completed',
  'douyin_verified',
  'meituan_verified',
  'aa_paid',
  'wine_deposited',
  'wine_collected',
  'recharge_paid',
};
final _noticeId = RegExp(r'^[a-f0-9]{64}$');
Never _invalid() =>
    throw const AuthFailure('SYSTEM_NOTICES_INVALID', '系统消息暂不可用');

class SystemNotice {
  const SystemNotice({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.read,
    required this.amountCents,
    required this.details,
    this.target,
  });
  final String id, kind;
  final DateTime occurredAt;
  final bool read;
  final int? amountCents;
  final List<(String, dynamic)> details;
  final Map<String, String>? target;
  factory SystemNotice.parse(dynamic raw) {
    if (raw is! Map ||
        raw['noticeRef'] is! String ||
        !_noticeId.hasMatch(raw['noticeRef']) ||
        !systemNoticeKinds.contains(raw['kind']) ||
        raw['read'] is! bool ||
        raw['occurredAt'] is! String) {
      _invalid();
    }
    final date = DateTime.tryParse(raw['occurredAt']);
    if (date == null || !raw['occurredAt'].endsWith('Z')) _invalid();
    final amount = raw['amountCents'];
    if (amount != null &&
        (amount is! int || amount < 1 || amount > 100000000)) {
      _invalid();
    }
    final items = raw['details'];
    if (items is! List || items.length > 12) _invalid();
    const labels = {
      'store',
      'table',
      'order',
      'products',
      'receipt',
      'quantity',
      'remaining',
      'expires',
      'channel',
      'account',
      'gift',
    };
    final details = <(String, dynamic)>[];
    for (final item in items) {
      if (item is! Map || !labels.contains(item['label'])) _invalid();
      final value = item['value'];
      if (value is String
          ? value.length > 2000
          : value is! Map ||
                ['zh-CN', 'en', 'zh-TW', 'th'].any(
                  (key) =>
                      value[key] is! String ||
                      (value[key] as String).length > 2000,
                )) {
        _invalid();
      }
      details.add((
        item['label'] as String,
        value is Map ? Map<String, String>.from(value) : value,
      ));
    }
    final target = raw['target'];
    if (target != null &&
        (target is! Map ||
            !{
              'order',
              'storage',
              'vouchers',
              'recharge',
            }.contains(target['kind']) ||
            target['reference'] is! String ||
            (target['reference'] as String).isEmpty ||
            target['reference'].length > 128)) {
      _invalid();
    }
    return SystemNotice(
      id: raw['noticeRef'],
      kind: raw['kind'],
      occurredAt: date,
      read: raw['read'],
      amountCents: amount,
      details: List.unmodifiable(details),
      target: target == null ? null : Map<String, String>.from(target),
    );
  }
  SystemNotice asRead() => SystemNotice(
    id: id,
    kind: kind,
    occurredAt: occurredAt,
    read: true,
    amountCents: amountCents,
    details: details,
    target: target,
  );
}

class SystemNoticeSummary {
  const SystemNoticeSummary({
    required this.unreadCount,
    required this.highWaterSequence,
    required this.latest,
  });
  final int unreadCount;
  final String? highWaterSequence;
  final SystemNotice? latest;
  factory SystemNoticeSummary.parse(dynamic raw) {
    if (raw is! Map || raw['unreadCount'] is! int || raw['unreadCount'] < 0) {
      _invalid();
    }
    final sequence = raw['highWaterSequence'];
    if (sequence != null &&
        (sequence is! String ||
            !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(sequence))) {
      _invalid();
    }
    final latest = raw['latest'] == null
        ? null
        : SystemNotice.parse(raw['latest']);
    if ((sequence == null) != (latest == null) ||
        (latest == null && raw['unreadCount'] != 0)) {
      _invalid();
    }
    return SystemNoticeSummary(
      unreadCount: raw['unreadCount'],
      highWaterSequence: sequence,
      latest: latest,
    );
  }
}

class SystemNoticePageData {
  const SystemNoticePageData(this.notices, this.nextBeforeNotice, this.summary);
  final List<SystemNotice> notices;
  final String? nextBeforeNotice;
  final SystemNoticeSummary summary;
  factory SystemNoticePageData.parse(dynamic raw) {
    final summary = SystemNoticeSummary.parse(raw);
    if (raw['notices'] is! List || raw['notices'].length > 20) _invalid();
    final notices = (raw['notices'] as List).map(SystemNotice.parse).toList();
    if (notices.map((n) => n.id).toSet().length != notices.length) _invalid();
    final next = raw['nextBeforeNotice'];
    if (next != null &&
        (next is! String ||
            !_noticeId.hasMatch(next) ||
            notices.length != 20 ||
            next != notices.last.id)) {
      _invalid();
    }
    return SystemNoticePageData(List.unmodifiable(notices), next, summary);
  }
}

class SystemNoticesRepository {
  const SystemNoticesRepository({
    required this.readSession,
    required this.request,
  });
  factory SystemNoticesRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl),
        sessions = SecureSessionStore();
    return SystemNoticesRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;
  List<String>? _identity(Map<String, dynamic>? session) {
    final account = session?['account'];
    final parts = [
      session?['sessionId'],
      session?['apiKeyId'],
      session?['apiKey'],
      account is Map ? account['userAccount'] : null,
    ];
    return parts.any((p) => p is! String || p.isEmpty)
        ? null
        : parts.cast<String>();
  }

  Future<dynamic> _call(String id, Map<String, dynamic> params) async {
    final session = await readSession(), identity = _identity(session);
    if (identity == null) throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    final response = await request(id, params, session!);
    if (!listEquals(identity, _identity(await readSession()))) {
      throw const AuthFailure('SESSION_CHANGED', '登录状态已变化');
    }
    return response['result'];
  }

  Future<SystemNoticePageData> list({String? beforeNotice}) async {
    if (beforeNotice != null && !_noticeId.hasMatch(beforeNotice)) _invalid();
    return SystemNoticePageData.parse(
      await _call('K261002001960', {'beforeNotice': ?beforeNotice}),
    );
  }

  Future<SystemNoticeSummary> markRead({
    List<String>? ids,
    String? throughSequence,
  }) async {
    if ((ids == null) == (throughSequence == null) ||
        (ids != null &&
            (ids.isEmpty ||
                ids.length > 50 ||
                ids.any((id) => !_noticeId.hasMatch(id)))) ||
        (throughSequence != null &&
            !RegExp(r'^[1-9][0-9]{0,19}$').hasMatch(throughSequence))) {
      _invalid();
    }
    return SystemNoticeSummary.parse(
      await _call('K261002001961', {
        'noticeRefs': ?ids,
        'throughSequence': ?throughSequence,
      }),
    );
  }
}
