import 'package:flutter/foundation.dart';

import 'dart:async';

import '../../messaging/data/chat_history_store.dart';

import 'contact_name_index.dart';

import '../../messaging/data/messaging_repository.dart';

class MemberContact {
  const MemberContact({
    required this.account,
    required this.nickname,
    required this.bio,
    this.remark,
    this.gender,
  });
  final String account;
  final String nickname;
  final String bio;
  final String? remark;
  final int? gender;
  String get displayName => remark ?? nickname;

  factory MemberContact.fromJson(Map<String, dynamic> json) {
    final account = json['peer'];
    final nickname = json['nickname'];
    if (account is! String || account.isEmpty || nickname is! String) {
      throw const FormatException('Invalid contact');
    }
    final remark = (json['remark'] as String?)?.trim();
    final gender = json['gender'];
    return MemberContact(
      account: account,
      nickname: nickname,
      remark: remark == null || remark.isEmpty ? null : remark,
      bio: (json['bio'] as String?) ?? '',
      gender: gender == 1 || gender == 2 ? gender as int : null,
    );
  }
}

/// An atomic, account-bound contact snapshot. Never mixes partial refresh pages
/// with the prior snapshot: removed friendships disappear only after a full read.
class ContactsController extends ChangeNotifier {
  ContactsController(
    this.repository, {
    Future<ChatHistoryStore> Function()? historyStore,
  }) : _historyStore =
           historyStore ?? (() => ChatHistoryStore.open(repository.account));
  final Future<ChatHistoryStore> Function() _historyStore;
  bool _restoring = false;
  final MessagingRepository repository;
  List<MemberContact> _contacts = const [];
  List<MemberContact> get contacts => _contacts;
  Future<void>? _refreshing;
  bool _disposed = false;
  int _generation = 0;
  String? error;
  bool hasSnapshot = false;
  bool _refreshAgain = false;
  int pendingRequests = 0;
  int _requestsGeneration = 0;

  List<MemberContact> search(String query) {
    return _contacts
        .where(
          (c) => contactNameMatches(
            nickname: c.nickname,
            remark: c.remark,
            account: c.account,
            query: query,
          ),
        )
        .toList();
  }

  Future<void> refresh({bool afterCurrent = false}) {
    if (_disposed) return Future.value();
    if (!_restoring && !hasSnapshot) {
      _restoring = true;
      unawaited(_restore(_generation));
    }
    final active = _refreshing;
    if (active != null) {
      if (afterCurrent) _refreshAgain = true;
      return active;
    }
    final generation = _generation;
    return _refreshing = _drainRefresh(generation).whenComplete(() {
      if (generation == _generation) _refreshing = null;
    });
  }

  Future<void> _drainRefresh(int generation) async {
    do {
      _refreshAgain = false;
      await _fetch(generation);
    } while (!_disposed && generation == _generation && _refreshAgain);
  }

  /// Count only unresolved incoming requests; sent and resolved rows are not badges.
  Future<void> refreshRequests() async {
    if (_disposed) return;
    final generation = ++_requestsGeneration;
    final pending = <String>{};
    var offset = 0;
    try {
      while (true) {
        final result = await repository.requests(offset: offset);
        if (_disposed || generation != _requestsGeneration) return;
        final items = result['items'] as List;
        for (final raw in items) {
          final row = raw as Map;
          if (row['recipient'] == repository.account &&
              row['requestStatus'] == 'pending') {
            final id = row['requestId'];
            if (id is! String || id.isEmpty) {
              throw const FormatException('Invalid request identity');
            }
            pending.add(id);
          }
        }
        if (result['hasMore'] != true) break;
        if (items.isEmpty) {
          throw const FormatException('Empty request continuation');
        }
        offset += items.length;
      }
      pendingRequests = pending.length;
      notifyListeners();
    } catch (_) {
      // Preserve the last confirmed count during temporary connection failures.
    }
  }

  Future<void> _fetch(int generation) async {
    final started = DateTime.now().microsecondsSinceEpoch;
    final next = <String, MemberContact>{};
    var offset = 0;
    try {
      while (true) {
        final result = await repository.contacts(offset: offset);
        if (_disposed || generation != _generation) return;
        final items = result['items'] as List;
        for (final raw in items) {
          final contact = MemberContact.fromJson(
            Map<String, dynamic>.from(raw as Map),
          );
          next[contact.account] = contact;
        }
        if (result['hasMore'] != true) break;
        if (items.isEmpty) {
          throw const FormatException('Empty contact continuation');
        }
        offset += items.length;
      }
      _contacts = List.unmodifiable(next.values);
      hasSnapshot = true;
      error = null;
      notifyListeners();
      unawaited(_save(_contacts, started, generation));
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> _restore(int generation) async {
    try {
      final store = await _historyStore();
      if (store.account != repository.account) return;
      final rows = await store.contactSnapshot();
      if (_disposed ||
          generation != _generation ||
          hasSnapshot ||
          rows == null) {
        return;
      }
      final contacts = rows.map(MemberContact.fromJson).toList();
      _contacts = List.unmodifiable(contacts);
      hasSnapshot = true;
      notifyListeners();
    } catch (_) {
      // Unavailable/corrupt cache must never suppress the network refresh.
    }
  }

  Future<void> _save(
    List<MemberContact> contacts,
    int started,
    int generation,
  ) async {
    try {
      final store = await _historyStore();
      if (store.account != repository.account) return;
      if (_disposed || generation != _generation) return;
      await store.saveContactSnapshot(
        contacts
            .map(
              (contact) => {
                'peer': contact.account,
                'nickname': contact.nickname,
                'remark': contact.remark,
                'bio': contact.bio,
                'gender': contact.gender,
              },
            )
            .toList(),
        started,
      );
    } catch (_) {
      // Cache failure does not turn a confirmed server result into an error.
    }
  }

  /// Call on session change before opening the next account's controller.
  void invalidate() {
    _generation++;
    _requestsGeneration++;
    _refreshAgain = false;
    _restoring = false;
    pendingRequests = 0;
    _refreshing = null;
    _contacts = const [];
    hasSnapshot = false;
    error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    invalidate();
    super.dispose();
  }
}
