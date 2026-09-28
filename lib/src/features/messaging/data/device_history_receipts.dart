import 'dart:async';

import 'chat_history_store.dart';

final _historyReceiptFlights = <String, Future<void>>{};
final _historyReceiptRetryAt = <String, DateTime>{};

/// Best-effort transport, durable SQLite queue. Failure never turns a locally
/// saved message into a failed send, and never discards an unconfirmed receipt.
Future<void> flushDeviceHistoryReceipts(
  String account,
  Future<Map<String, dynamic>> Function(String, Map<String, dynamic>) call, {
  ChatHistoryStore? store,
}) {
  final previous = _historyReceiptFlights[account];
  if (previous != null) return previous;
  if ((_historyReceiptRetryAt[account] ?? DateTime(1970)).isAfter(
    DateTime.now(),
  )) {
    return Future.value();
  }
  final future = () async {
    try {
      final history = store ?? await ChatHistoryStore.open(account);
      if (history.account != account) {
        throw StateError('History account mismatch');
      }
      final groups = await history.pendingDeviceReceipts();
      for (final entry in groups.entries) {
        final group = entry.key.startsWith('group:');
        final target = entry.key.substring(group ? 6 : 7);
        final result = await call(group ? 'K260913000621' : 'K260913000604', {
          group ? 'groupId' : 'peer': target,
          'acknowledgeOnly': true,
          'savedMessageIds': entry.value,
        });
        if (result['deviceHistory'] != true) {
          _historyReceiptRetryAt[account] = DateTime.now().add(
            const Duration(minutes: 1),
          );
          return;
        }
        final settled = <String>[];
        for (final field in ['confirmed', 'conflicts', 'unavailable']) {
          final ids = result[field];
          if (ids is! List ||
              ids.any((id) => id is! String || !entry.value.contains(id))) {
            throw const FormatException('Invalid device history receipt');
          }
          settled.addAll(ids.cast<String>());
        }
        if (settled.toSet().length != settled.length ||
            settled.length != entry.value.length) {
          throw const FormatException('Incomplete device history receipt');
        }
        await history.settleDeviceReceipts(entry.key, settled);
      }
    } catch (_) {
      _historyReceiptRetryAt[account] = DateTime.now().add(
        const Duration(seconds: 10),
      );
    }
  }();
  _historyReceiptFlights[account] = future;
  unawaited(
    future.whenComplete(() {
      if (identical(_historyReceiptFlights[account], future)) {
        _historyReceiptFlights.remove(account);
      }
    }),
  );
  return future;
}
