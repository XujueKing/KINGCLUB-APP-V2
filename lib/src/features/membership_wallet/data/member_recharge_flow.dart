import 'dart:convert';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/data/auth_repository_provider.dart';
import 'member_recharge_journal.dart';
import 'member_recharge_repository.dart';
import 'member_recharge_result.dart';

/// User-driven operations only. No background creation, retry loop or payment.
class MemberRechargeFlow {
  MemberRechargeFlow({
    MemberRechargeJournal? journal,
    MemberRechargeRepository? repository,
    Future<String?> Function()? account,
    int Function()? generation,
    String? baseUrl,
  }) : journal = journal ?? MemberRechargeJournal(),
       repository = repository ?? MemberRechargeRepository(),
       _account = account ?? _sessionAccount,
       _generation = generation ?? (() => MemberQrMemory.generation),
       baseUrl = baseUrl ?? kingclubApiBaseUrl;
  final MemberRechargeJournal journal;
  final MemberRechargeRepository repository;
  final Future<String?> Function() _account;
  final int Function() _generation;
  final String baseUrl;
  Future<String?> currentAccount() => _account();
  bool _busy = false;
  static Future<String?> _sessionAccount() async {
    final session = await SecureSessionStore().readSession();
    return (session?['account'] as Map?)?['userAccount'] as String?;
  }

  Future<T> _operation<T>(
    MemberRechargeRequest request,
    bool Function() stillCurrent,
    Future<T> Function(Future<void> Function()) work,
  ) async {
    if (_busy) throw StateError('RECHARGE_BUSY');
    _busy = true;
    final epoch = _generation();
    Future<void> check() async {
      if (!stillCurrent() ||
          epoch != _generation() ||
          baseUrl != request.baseUrl) {
        throw StateError('RECHARGE_CONTEXT_CHANGED');
      }
      final account = await _account();
      if (account != request.userAccount ||
          epoch != _generation() ||
          !stillCurrent()) {
        throw StateError('RECHARGE_CONTEXT_CHANGED');
      }
    }

    try {
      await check();
      return await work(check);
    } finally {
      _busy = false;
    }
  }

  Future<MemberRechargeOriginal> create(
    MemberRechargeRequest request, {
    required bool Function() stillCurrent,
  }) => _operation(request, stillCurrent, (check) async {
    await journal.save(request);
    await check();
    final result = await _prepare(request);
    await check();
    return result;
  });

  /// Replays the saved create key to recover the original UUID, then queries it.
  /// If an earlier create never reached the server this creates that same order,
  /// not a payment. Must be explicitly requested by the member.
  Future<MemberRechargeResult> recover(
    MemberRechargeRequest request, {
    required bool Function() stillCurrent,
  }) => _operation(request, stillCurrent, (check) async {
    final rows = await journal.load(
      baseUrl: request.baseUrl,
      userAccount: request.userAccount,
    );
    if (!rows.any(
      (r) => jsonEncode(r.encoded) == jsonEncode(request.encoded),
    )) {
      throw StateError('RECHARGE_ORIGINAL_NOT_SAVED');
    }
    await check();
    final original = await _prepare(request);
    await check();
    final result = await repository.query(
      original,
      userAccount: request.userAccount,
    );
    await check();
    if (result.credited) {
      await journal.acknowledge(request, original, result);
      await check();
    }
    return result;
  });
  Future<MemberRechargeOriginal> _prepare(MemberRechargeRequest request) =>
      repository.prepare(
        requestId: request.requestId,
        storeRef: request.storeRef,
        campaignRef: request.campaignRef,
        campaignRevision: request.campaignRevision,
        channel: request.channel,
        expectedUserAccount: request.userAccount,
      );
}
