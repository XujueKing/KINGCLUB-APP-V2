import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/session/secure_session_store.dart';
import 'system_notices_repository.dart';

/// One account-scoped inbox shared by the shell badge and its conversation.
class SystemNoticesController extends ChangeNotifier {
  SystemNoticesController(this.repository) {
    _session = SecureSessionStore.changes.stream.listen((_) => invalidate());
  }
  final SystemNoticesRepository repository;
  StreamSubscription<void>? _session;
  List<SystemNotice> notices = [];
  SystemNoticeSummary summary = const SystemNoticeSummary(
    unreadCount: 0,
    highWaterSequence: null,
    latest: null,
  );
  String? next;
  bool loading = false, failed = false, reading = false;
  bool _disposed = false, _loadedMore = false;
  bool _refreshQueued = false;
  int _epoch = 0;
  Future<void> refresh({bool more = false}) async {
    if (_disposed || (more && next == null)) return;
    if (loading || reading) {
      if (!more) _refreshQueued = true;
      return;
    }
    final epoch = _epoch, cursor = more ? next : null;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final page = await repository.list(beforeNotice: cursor);
      if (_disposed || epoch != _epoch) return;
      final merged = <String, SystemNotice>{
        if (more || _loadedMore)
          for (final n in notices) n.id: n,
        for (final n in page.notices) n.id: n,
      };
      notices = merged.values.toList()
        ..sort((a, b) {
          final cmp = b.occurredAt.compareTo(a.occurredAt);
          return cmp == 0 ? b.id.compareTo(a.id) : cmp;
        });
      if (more || !_loadedMore) next = page.nextBeforeNotice;
      _loadedMore |= more;
      summary = page.summary;
    } catch (_) {
      if (!_disposed && epoch == _epoch) failed = true;
    } finally {
      if (!_disposed && epoch == _epoch) {
        loading = false;
        notifyListeners();
        _drainRefresh();
      }
    }
  }

  Future<void> markRead({String? id, String? throughSequence}) async {
    if (_disposed ||
        reading ||
        loading ||
        (id == null &&
            throughSequence == null &&
            summary.highWaterSequence == null)) {
      return;
    }
    final epoch = ++_epoch;
    reading = true;
    failed = false;
    notifyListeners();
    try {
      final result = await repository.markRead(
        ids: id == null ? null : [id],
        throughSequence: id == null
            ? throughSequence ?? summary.highWaterSequence
            : null,
      );
      if (_disposed || epoch != _epoch) return;
      notices = [
        for (final n in notices)
          if (id == null || n.id == id) n.asRead() else n,
      ];
      summary = result;
    } catch (_) {
      if (!_disposed && epoch == _epoch) failed = true;
    } finally {
      if (!_disposed && epoch == _epoch) {
        reading = false;
        notifyListeners();
        _drainRefresh();
      }
    }
  }

  void _drainRefresh() {
    if (_refreshQueued && !_disposed) {
      _refreshQueued = false;
      unawaited(refresh());
    }
  }

  void invalidate() {
    _epoch++;
    notices = [];
    next = null;
    loading = false;
    reading = false;
    failed = false;
    _loadedMore = false;
    _refreshQueued = false;
    summary = const SystemNoticeSummary(
      unreadCount: 0,
      highWaterSequence: null,
      latest: null,
    );
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _session?.cancel();
    super.dispose();
  }
}
