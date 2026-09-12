import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/member_qr_memory.dart';
import 'package:kingclub/src/features/profile_settings/data/profile_repository.dart';

class Repo extends ProfileRepository {
  int calls = 0;
  Completer<Map<String, dynamic>>? delayed;
  @override
  Future<Map<String, dynamic>> call(
    String id,
    Map<String, dynamic> params,
  ) async {
    calls++;
    return delayed == null
        ? {'code': 'test', 'ttlSeconds': 600}
        : delayed!.future;
  }
}

void main() {
  setUp(MemberQrMemory.clear);
  test('deduplicates prefetch and opening; reuses valid code', () async {
    final r = Repo();
    await Future.wait([r.memberQr(), r.memberQr()]);
    await r.memberQr();
    expect(r.calls, 1);
    expect(MemberQrMemory.valid?['code'], 'test');
  });
  test('session clear discards late response and cached data', () async {
    final r = Repo()..delayed = Completer();
    final pending = r.memberQr();
    final assertion = expectLater(pending, throwsStateError);
    MemberQrMemory.clear();
    r.delayed!.complete({'code': 'old', 'ttlSeconds': 600});
    await assertion;
    expect(MemberQrMemory.valid, isNull);
  });
  test('expired code is never reused', () async {
    MemberQrMemory.put({'code': 'expired', 'ttlSeconds': 0});
    expect(MemberQrMemory.valid, isNull);
    final r = Repo();
    await r.memberQr();
    expect(r.calls, 1);
  });
}
