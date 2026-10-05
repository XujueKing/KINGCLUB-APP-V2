import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../profile_settings/data/profile_repository.dart';
import 'member_balance_snapshot.dart';

class StoreDebitNotice {
  StoreDebitNotice(this.operationRef, this.store, this.amount);
  final String operationRef;
  final MemberStoreBalance store;
  final BigInt amount;
}

/// An identity scan is not payment. Only committed spend records can trigger this.
class StoreDebitWatch {
  StoreDebitWatch({
    required this.active,
    required this.onPaid,
    this.load,
    this.onSnapshot,
    Stream<Map<String, dynamic>>? events,
  }) {
    subscription = (events ?? KingclubRealtime.shared.events).listen((e) {
      if (['balance.changed', 'connection.ready'].contains(e['eventType'])) {
        check();
      }
    });
    timer = Timer.periodic(const Duration(seconds: 3), (_) => check());
    scheduleMicrotask(check);
  }
  final void Function(MemberBalanceSnapshot)? onSnapshot;
  final bool Function() active;
  final void Function(StoreDebitNotice) onPaid;
  final Future<Map<String, dynamic>> Function()? load;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Timer? timer;
  bool disposed = false, busy = false;
  int generation = MemberQrMemory.generation;
  DateTime? baseline;
  final seen = <String>{};
  Future<void> check() async {
    if (disposed ||
        busy ||
        !active() ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    if (generation != MemberQrMemory.generation) {
      generation = MemberQrMemory.generation;
      baseline = null;
      seen.clear();
    }
    final current = generation;
    busy = true;
    try {
      final raw =
          await (load?.call() ?? ProfileRepository().call('K260930000508', {}));
      if (disposed || current != MemberQrMemory.generation) return;
      final snapshot = MemberBalanceSnapshot.parse(raw);
      onSnapshot?.call(snapshot);
      final rows = (raw['recentDebits'] as List? ?? []).cast<Map>();
      final old = baseline;
      baseline ??= snapshot.at;
      for (final row in rows.reversed) {
        final id = row['operationRef'] as String;
        final fresh = seen.add(id);
        if (old == null ||
            !fresh ||
            DateTime.parse(row['paidAt'] as String).isBefore(old)) {
          continue;
        }
        final store = snapshot.stores
            .where((s) => s.ref == row['storeRef'])
            .firstOrNull;
        final amount = balanceCents(row['totalCents']);
        if (store != null && amount > BigInt.zero && active()) {
          onPaid(StoreDebitNotice(id, store, amount));
        }
      }
    } catch (_) {
      /* Event and foreground poll retry; never infer success from balance changes. */
    } finally {
      busy = false;
    }
  }

  void dispose() {
    disposed = true;
    timer?.cancel();
    subscription?.cancel();
  }
}
