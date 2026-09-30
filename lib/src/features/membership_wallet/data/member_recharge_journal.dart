import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'member_recharge_repository.dart';
import 'member_recharge_result.dart';

/// Persists only the original selection, never a payment code or session secret.
class MemberRechargeRequest {
  MemberRechargeRequest({
    required this.baseUrl,
    required this.userAccount,
    required this.storeRef,
    required this.requestId,
    required this.campaignRef,
    required this.campaignRevision,
    required this.channel,
  }) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        ![
          userAccount,
          storeRef,
          campaignRef,
        ].every((v) => RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(v)) ||
        !RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ).hasMatch(requestId) ||
        campaignRevision < 1 ||
        campaignRevision > 9007199254740991 ||
        !['wechat', 'alipay'].contains(channel)) {
      throw const FormatException('Invalid saved recharge request');
    }
  }
  final String baseUrl, userAccount, storeRef, requestId, campaignRef, channel;
  final int campaignRevision;
  Map<String, dynamic> get encoded => {
    'baseUrl': baseUrl,
    'userAccount': userAccount,
    'storeRef': storeRef,
    'requestId': requestId,
    'campaignRef': campaignRef,
    'campaignRevision': campaignRevision,
    'channel': channel,
  };
  factory MemberRechargeRequest.decode(Object? raw) {
    const keys = {
      'baseUrl',
      'userAccount',
      'storeRef',
      'requestId',
      'campaignRef',
      'campaignRevision',
      'channel',
    };
    if (raw is! Map<String, dynamic> ||
        raw.length != keys.length ||
        !raw.keys.every(keys.contains) ||
        !keys
            .where((k) => k != 'campaignRevision')
            .every((k) => raw[k] is String) ||
        raw['campaignRevision'] is! int) {
      throw const FormatException('Invalid saved recharge request');
    }
    return MemberRechargeRequest(
      baseUrl: raw['baseUrl'] as String,
      userAccount: raw['userAccount'] as String,
      storeRef: raw['storeRef'] as String,
      requestId: raw['requestId'] as String,
      campaignRef: raw['campaignRef'] as String,
      campaignRevision: raw['campaignRevision'] as int,
      channel: raw['channel'] as String,
    );
  }
  bool sameScope(MemberRechargeRequest other) =>
      baseUrl == other.baseUrl &&
      userAccount == other.userAccount &&
      storeRef == other.storeRef;
}

/// One unresolved request per member/store. Logout never deletes this journal.
/// Write and read back before calling prepare. Corrupt storage fails closed.
class MemberRechargeJournal {
  MemberRechargeJournal({
    FlutterSecureStorage? storage,
    this._read,
    this._write,
  }) : _storage = storage ?? const FlutterSecureStorage();
  static const key = 'kingclub.member.recharge.pending.v1';
  final FlutterSecureStorage _storage;
  final Future<String?> Function()? _read;
  final Future<void> Function(String)? _write;
  static Future<void>? _tail;
  Future<T> _exclusive<T>(Future<T> Function() task) {
    final previous = _tail;
    final result = previous == null
        ? Future<T>.sync(task)
        : previous.then((_) => task());
    // Keep serialization across instances while busy, but do not retain an
    // idle Future (and its originating async zone) after the last operation.
    late final Future<void> tail;
    void release() {
      if (identical(_tail, tail)) _tail = null;
    }

    tail = result.then<void>(
      (_) => release(),
      onError: (Object _, StackTrace _) => release(),
    );
    _tail = tail;
    return result;
  }

  Future<String?> _readText() => _read?.call() ?? _storage.read(key: key);
  Future<List<MemberRechargeRequest>> _rows() async {
    final text = await _readText();
    if (text == null) return [];
    if (text.length > 1000000) throw StateError('RECHARGE_JOURNAL_INVALID');
    final raw = jsonDecode(text);
    if (raw is! List || raw.length > 100) {
      throw StateError('RECHARGE_JOURNAL_INVALID');
    }
    final rows = raw.map(MemberRechargeRequest.decode).toList();
    final scopes = <String>{}, requests = <String>{};
    for (final row in rows) {
      if (!scopes.add(
            jsonEncode([row.baseUrl, row.userAccount, row.storeRef]),
          ) ||
          !requests.add(
            jsonEncode([row.baseUrl, row.userAccount, row.requestId]),
          )) {
        throw StateError('RECHARGE_JOURNAL_INVALID');
      }
    }
    return rows;
  }

  Future<List<MemberRechargeRequest>> load({
    required String baseUrl,
    required String userAccount,
  }) => _exclusive(() async {
    final rows = await _rows();
    return List.unmodifiable(
      rows.where((r) => r.baseUrl == baseUrl && r.userAccount == userAccount),
    );
  });
  Future<void> save(MemberRechargeRequest request) => _exclusive(() async {
    final rows = await _rows();
    for (final row in rows) {
      if (row.sameScope(request) ||
          (row.baseUrl == request.baseUrl &&
              row.userAccount == request.userAccount &&
              row.requestId == request.requestId)) {
        if (jsonEncode(row.encoded) == jsonEncode(request.encoded)) return;
        throw StateError('RECHARGE_ORIGINAL_MUST_BE_RECOVERED');
      }
    }
    if (rows.length >= 100) throw StateError('RECHARGE_JOURNAL_FULL');
    final text = jsonEncode([...rows, request].map((r) => r.encoded).toList());
    if (_write != null) {
      await _write(text);
    } else {
      await _storage.write(key: key, value: text);
    }
    if (await _readText() != text) {
      throw StateError('RECHARGE_JOURNAL_WRITE_UNCONFIRMED');
    }
  });

  Future<void> acknowledge(
    MemberRechargeRequest request,
    MemberRechargeOriginal original,
    MemberRechargeResult result,
  ) => _exclusive(() async {
    if (!result.credited ||
        result.storeRef != request.storeRef ||
        result.userAccount != request.userAccount ||
        original.storeRef != request.storeRef ||
        original.channel != request.channel ||
        result.rechargeRef != original.rechargeRef ||
        result.principalCents != original.principalCents ||
        result.giftCents != original.giftCents) {
      throw StateError('RECHARGE_ACKNOWLEDGEMENT_INVALID');
    }
    final rows = await _rows();
    final index = rows.indexWhere((r) => r.sameScope(request));
    if (index < 0) return;
    if (jsonEncode(rows[index].encoded) != jsonEncode(request.encoded)) {
      throw StateError('RECHARGE_ORIGINAL_MISMATCH');
    }
    rows.removeAt(index);
    final text = jsonEncode(rows.map((r) => r.encoded).toList());
    if (_write != null) {
      await _write(text);
    } else {
      await _storage.write(key: key, value: text);
    }
    if (await _readText() != text) {
      throw StateError('RECHARGE_JOURNAL_WRITE_UNCONFIRMED');
    }
  });
}
