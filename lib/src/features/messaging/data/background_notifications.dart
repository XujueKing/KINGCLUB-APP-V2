import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/secure_session_store.dart';
import 'call_repository.dart';
import 'foreground_message_notice.dart';
import 'group_call_repository.dart';
import 'messaging_repository.dart';

/// Validates incoming events for either the UI fallback or service-owned engine.
/// Vendor push is still required when Android cannot run either receiver.
class BackgroundNotifications {
  static const channel = MethodChannel('kingclub/local-notifications');
  final _messages = ForegroundMessageNoticeResolver();
  final _calls = <String>{};
  int _epoch = 0;
  bool _foreground = true;
  Future<void> _queue = Future.value();

  void foreground(bool value) {
    _foreground = value;
    _epoch++;
    if (value) {
      _calls.clear();
      unawaited(_invoke('clearCalls'));
    }
  }

  void reset() {
    _epoch++;
    _messages.clear();
    _calls.clear();
    unawaited(_invoke('bind', {'session': null}));
  }

  Future<bool> _invoke(String method, [Map<String, dynamic>? args]) async {
    try {
      final shown = await channel.invokeMethod<bool>(method, args) == true;
      if (method == 'show') debugPrint('ChatBackground: localShown=$shown');
      return shown;
    } on MissingPluginException {
      // Non-Android platforms retain their own push implementation.
    } on PlatformException {
      // Do not disable vendor fallback when local notification fails.
    }
    return false;
  }

  void notify(Map<String, dynamic> event) {
    final epoch = _epoch;
    _queue = _queue
        .then((_) async {
          if (_foreground || epoch != _epoch) return;
          await _handle(event, epoch);
        })
        .catchError((Object error) {
          debugPrint('ChatBackground: failed ${error.runtimeType}');
        });
  }

  Future<void> _handle(Map<String, dynamic> event, int epoch) async {
    final store = SecureSessionStore();
    final session = await store.readSession();
    final id = session?['sessionId'];
    if (id is! String || _foreground || epoch != _epoch) return;
    final repository = await MessagingRepository.open(installMediaRuntime: false);
    bool valid() => !_foreground && epoch == _epoch;
    Future<bool> authorized() async =>
        (await store.readSession())?['sessionId'] == id && valid();
    if (!await authorized()) return;
    await _invoke('bind', {'session': id});
    Future<bool> show(
      String target,
      bool group,
      bool call,
      int expiry,
      String eventId, {
      int unread = 0,
    }) async {
      if (!await authorized()) return false;
      return _invoke('show', {
        'session': id,
        'unread': unread,
        'destination': jsonEncode({
          'version': 1,
          'eventId': eventId,
          'recipient': repository.account,
          'target': target,
          'scope': group ? 'group' : 'direct',
          'kind': call ? 'call' : 'message',
          'expiresAt': expiry,
        }),
      });
    }

    final type = event['eventType'];
    debugPrint('ChatBackground: authorized event=$type');
    if (type == 'chat.changed' || type == 'chat.group.message') {
      final notice = await _messages.resolve(
        event: event,
        account: repository.account,
        page: (offset) => repository
            .conversations(offset: offset)
            .timeout(const Duration(seconds: 5)),
        valid: valid,
      );
      debugPrint('ChatBackground: messageEligible=${notice != null}');
      if (notice != null) {
        await show(
          notice.target,
          notice.group,
          false,
          DateTime.now().add(const Duration(hours: 12)).millisecondsSinceEpoch,
          const Uuid().v4(),
          unread: notice.unread,
        );
      }
    }
    if (type == 'chat.call.changed' ||
        type == 'chat.group.call.changed' ||
        type == 'connection.ready') {
      // Resolve scopes independently: a failed group request must not suppress
      // a direct incoming call (or remove a still-valid group invitation).
      for (final isGroup in [false, true]) {
        try {
          final live = <String>{};
          final now = DateTime.now().millisecondsSinceEpoch;
          if (!isGroup) {
            final direct = await CallRepository(repository)
                .read()
                .timeout(const Duration(seconds: 5));
            if (!await authorized()) return;
            if (direct != null &&
                direct.callee == repository.account &&
                direct.phase == CallPhase.ringing &&
                direct.deadlineMs > now) {
              live.add(direct.id);
              if (!_calls.contains(direct.id) &&
                  await show(
                    direct.caller,
                    false,
                    true,
                    direct.deadlineMs,
                    direct.id,
                  )) {
                _calls.add(direct.id);
              }
            }
          } else {
            final group = await GroupCallRepository(repository)
                .current()
                .timeout(const Duration(seconds: 5));
            if (!await authorized()) return;
            if (group != null && group.endedAtMs == null) {
              for (final participant in group.participants) {
                if (participant.account != repository.account ||
                    participant.phase != GroupCallPhase.invited ||
                    participant.deadlineMs <= now) {
                  continue;
                }
                live.add(group.id);
                if (!_calls.contains(group.id) &&
                    await show(
                      group.groupId,
                      true,
                      true,
                      participant.deadlineMs,
                      group.id,
                    )) {
                  _calls.add(group.id);
                }
              }
            }
          }
          if (!await authorized()) return;
          await _invoke('reconcileCalls', {
            'session': id,
            'scope': isGroup ? 'group' : 'direct',
            'live': live.toList(),
          });
        } catch (_) {
          // Unknown state is not an ended call. Native expiry remains active.
        }
      }
    }
  }
}
