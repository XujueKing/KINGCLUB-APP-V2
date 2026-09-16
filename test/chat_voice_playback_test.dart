import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_playback.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';

class Output implements ChatVoiceOutput {
  final plays = <String>[];
  int stops = 0;
  int disposals = 0;
  bool failStop = false, failPlay = false;
  Completer<void>? stopGate;
  final done = StreamController<void>.broadcast();
  @override
  Stream<void> get completed => done.stream;
  @override
  Future<void> play(String path) async {
    plays.add(path);
    if (failPlay) throw StateError("decoder rejected cache");
  }

  @override
  Future<void> stop() async {
    stops++;
    await stopGate?.future;
    if (failStop) throw StateError('native stop failed');
  }

  @override
  Future<void> dispose() {
    disposals++;
    return done.close();
  }
}

Map<String, dynamic> grant(String message, {bool group = false}) => {
  'messageId': message,
  'voice': {
    'fileId': '12345678-1234-1234-1234-123456789012',
    'durationMs': 2000,
    'contentType': 'audio/mp4',
    'path': '/kingclub/${group ? 'group-chat-voice' : 'chat-voice'}/$message',
    'headers': {'authorization': 'Bearer private'},
  },
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final downloadFailure in [false, true]) {
    test(
      'network failure can retry after reconnect: download=$downloadFailure',
      () async {
        final output = Output();
        var offline = true, requests = 0;
        final repo = MessagingRepository(
          account: 'me',
          call: (_, p) async {
            requests++;
            if (offline && !downloadFailure) {
              throw const AuthFailure('NETWORK_ERROR', 'network failed');
            }
            return grant(p['messageId'] as String, group: true);
          },
        );
        final player = ChatVoicePlayback(
          output: output,
          events: const Stream.empty(),
          loadFile: (_, _, _, _) async {
            if (offline) {
              throw DioException(
                requestOptions: RequestOptions(path: '/voice'),
                type: DioExceptionType.connectionError,
              );
            }
            return File('/voice.m4a');
          },
        );
        addTearDown(player.dispose);
        await player.toggle(repo, 'one', group: true);
        expect(player.error, '网络连接失败，请联网后点击语音重试');
        expect(player.loading, isFalse);
        expect(player.activeId, isNull);
        expect(output.plays, isEmpty);
        offline = false;
        await player.toggle(repo, 'one', group: true);
        expect(requests, 2);
        expect(player.error, isNull);
        expect(output.plays, ['/voice.m4a']);
      },
    );
  }
  test('permission rejection is not reported as a network failure', () async {
    final output = Output();
    final player = ChatVoicePlayback(
      output: output,
      events: const Stream.empty(),
    );
    addTearDown(player.dispose);
    await player.toggle(
      MessagingRepository(
        account: 'me',
        call: (_, _) async {
          throw const AuthFailure('CHAT_ACCESS_DENIED', 'forbidden');
        },
      ),
      'one',
    );
    expect(player.error, '语音暂不可播放，请重试');
    expect(output.plays, isEmpty);
  });
  for (final action in ['stop', 'pause', 'replace']) {
    test(
      'waiting native stop cannot revive superseded audio: $action',
      () async {
        final output = Output()..stopGate = Completer<void>();
        final requested = <String>[];
        final repository = MessagingRepository(
          account: 'me',
          call: (_, params) async {
            final message = params['messageId'] as String;
            requested.add(message);
            return grant(message);
          },
        );
        final player = ChatVoicePlayback(
          output: output,
          events: const Stream.empty(),
          loadFile: (url, _, _, _) async => File('/${url.split('/').last}.m4a'),
        );
        addTearDown(player.dispose);
        final first = player.toggle(repository, 'one');
        await Future<void>.delayed(Duration.zero);
        expect(output.stops, 1);
        Future<void>? next;
        if (action == 'stop') {
          next = player.stop();
        } else if (action == 'pause') {
          player.didChangeAppLifecycleState(AppLifecycleState.paused);
        } else {
          next = player.toggle(repository, 'two');
        }
        output.stopGate!.complete();
        await first;
        await next;
        await Future<void>.delayed(Duration.zero);
        expect(requested, action == 'replace' ? ['two'] : isEmpty);
        expect(output.plays, action == 'replace' ? ['/two.m4a'] : isEmpty);
        expect(player.activeId, action == 'replace' ? 'two' : isNull);
        expect(player.loading, isFalse);
      },
    );
  }
  test(
    'decoder failure evicts only its object and retry authorizes again',
    () async {
      final output = Output()..failPlay = true;
      final evicted = <String>[];
      var grants = 0, loads = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (_, p) async {
          grants++;
          return grant(p['messageId'] as String);
        },
      );
      final player = ChatVoicePlayback(
        output: output,
        events: const Stream.empty(),
        loadFile: (_, _, _, _) async {
          loads++;
          return File('/fixture.m4a');
        },
        evictFile: (account, fileId) async {
          evicted.add('$account:$fileId');
        },
      );
      addTearDown(player.dispose);
      await player.toggle(repo, 'one');
      expect(player.error, isNotNull);
      expect(player.activeId, isNull);
      expect(evicted, ['me:12345678-1234-1234-1234-123456789012']);
      expect(output.stops, 2);
      output.failPlay = false;
      await player.toggle(repo, 'one');
      expect(grants, 2);
      expect(loads, 2);
      expect(player.activeId, 'one');
      expect(player.error, isNull);
      expect(evicted.length, 1);
    },
  );
  test('old completion during download cannot clear the new clip', () async {
    final output = Output();
    final pending = Completer<File>();
    final downloading = Completer<void>();
    var loads = 0;
    final repo = MessagingRepository(
      account: 'me',
      call: (_, p) async => grant(p['messageId'] as String),
    );
    final player = ChatVoicePlayback(
      output: output,
      events: const Stream.empty(),
      loadFile: (_, _, _, _) async {
        if (++loads == 1) return File('/one.m4a');
        if (!downloading.isCompleted) downloading.complete();
        return pending.future;
      },
    );
    addTearDown(player.dispose);
    await player.toggle(repo, 'one');
    final next = player.toggle(repo, 'two');
    await downloading.future;
    output.done.add(null);
    output.done.addError(StateError('previous clip failed during download'));
    await Future<void>.delayed(Duration.zero);
    expect(player.activeId, 'two');
    expect(player.loading, true);
    pending.complete(File('/two.m4a'));
    await next;
    expect(output.plays, ['/one.m4a', '/two.m4a']);
    expect(player.activeId, 'two');
    expect(player.loading, false);
    output.done.addError(StateError('native decoder failed after play'));
    await Future<void>.delayed(Duration.zero);
    expect(player.activeId, isNull);
    expect(player.error, '语音播放中断，请重试');
    await player.toggle(repo, 'two');
    expect(player.activeId, 'two');
    expect(player.error, isNull);
    output.done.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(player.activeId, isNull);
  });
  test('native stop failure still disposes output exactly once', () async {
    final output = Output()..failStop = true;
    final player = ChatVoicePlayback(
      output: output,
      events: const Stream.empty(),
    );
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(output.disposals, 1);
    player.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(output.disposals, 1);
  });
  test('each playback checks permission before private cache, and only one clip is active', () async {
    final output = Output();
    var requests = 0, loads = 0;
    var allowed = true;
    final repo = MessagingRepository(
      account: 'me',
      call: (id, p) async {
        expect(id, 'K260913000638');
        requests++;
        if (!allowed) throw StateError('blocked');
        return grant(p['messageId'] as String);
      },
    );
    final player = ChatVoicePlayback(
      output: output,
      events: const Stream.empty(),
      loadFile: (url, account, key, headers) async {
        loads++;
        expect(account, 'me');
        expect(headers['authorization'], 'Bearer private');
        return File('/fixture.m4a');
      },
    );
    addTearDown(player.dispose);
    await player.toggle(repo, 'one');
    expect(output.plays.length, 1);
    await player.toggle(repo, 'one');
    expect(player.activeId, null);
    await player.toggle(repo, 'one');
    expect(requests, 2);
    expect(output.plays.length, 2);
    await player.toggle(repo, 'two');
    expect(player.activeId, 'two');
    expect(output.plays.length, 3);
    allowed = false;
    await player.toggle(repo, 'three');
    expect(player.activeId, null);
    expect(loads, 3);
    expect(player.error, isNotNull);
  });
  test(
    'session change discards a late download and prevents future requests',
    () async {
      final output = Output(),
          pending = Completer<File>(),
          started = Completer<void>();
      var requests = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (_, p) async {
          requests++;
          return grant(p['messageId'] as String);
        },
      );
      final player = ChatVoicePlayback(
        output: output,
        events: const Stream.empty(),
        loadFile: (_, _, _, _) async {
          started.complete();
          return pending.future;
        },
      );
      addTearDown(player.dispose);
      final play = player.toggle(repo, 'one');
      await started.future;
      SecureSessionStore.changes.add(null);
      await Future<void>.delayed(Duration.zero);
      pending.complete(File('/late.m4a'));
      await play;
      expect(output.plays, isEmpty);
      await player.toggle(repo, 'two');
      expect(requests, 1);
    },
  );
  test(
    'group permission event stops playback and rejects late authorization',
    () async {
      final output = Output(),
          events = StreamController<Map<String, dynamic>>.broadcast(),
          pending = Completer<Map<String, dynamic>>(),
          started = Completer<void>();
      final repo = MessagingRepository(
        account: 'me',
        call: (id, p) async {
          expect(id, 'K260913000640');
          started.complete();
          return pending.future;
        },
      );
      final player = ChatVoicePlayback(
        output: output,
        events: events.stream,
        loadFile: (_, _, _, _) async => throw StateError('must not read cache'),
      );
      addTearDown(player.dispose);
      addTearDown(events.close);
      final play = player.toggle(repo, 'one', group: true);
      await started.future;
      events.add({'eventType': 'chat.group.changed'});
      await Future<void>.delayed(Duration.zero);
      pending.complete(grant('one', group: true));
      await play;
      expect(output.plays, isEmpty);
      expect(player.activeId, null);
    },
  );
  test(
    'group read preserves authorized audio but hidden media stops it',
    () async {
      final output = Output();
      final events = StreamController<Map<String, dynamic>>.broadcast();
      var allowed = true, requests = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (_, p) async {
          requests++;
          if (!allowed) throw StateError('hidden');
          return grant(p['messageId'] as String, group: true);
        },
      );
      final player = ChatVoicePlayback(
        output: output,
        events: events.stream,
        loadFile: (_, _, _, _) async => File('/fixture.m4a'),
      );
      addTearDown(player.dispose);
      addTearDown(events.close);
      await player.toggle(repo, 'one', group: true, groupId: 'current');
      final stops = output.stops;
      void read() => events.add({
        'eventType': 'chat.group.read',
        'data': {'groupId': 'current'},
      });
      read();
      await Future<void>.delayed(Duration.zero);
      expect(requests, 2);
      expect(player.activeId, 'one');
      expect(output.stops, stops);
      allowed = false;
      read();
      await Future<void>.delayed(Duration.zero);
      expect(player.activeId, isNull);
      expect(output.stops, stops + 1);
    },
  );
  test(
    'hidden event during authorization is rechecked after the stale grant',
    () async {
      final output = Output();
      final events = StreamController<Map<String, dynamic>>.broadcast();
      final pending = Completer<Map<String, dynamic>>();
      var requests = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (_, p) async {
          requests++;
          if (requests == 2) return pending.future;
          if (requests > 2) throw StateError('hidden');
          return grant(p['messageId'] as String, group: true);
        },
      );
      final player = ChatVoicePlayback(
        output: output,
        events: events.stream,
        loadFile: (_, _, _, _) async => File('/fixture.m4a'),
      );
      addTearDown(player.dispose);
      addTearDown(events.close);
      await player.toggle(repo, 'one', group: true, groupId: 'current');
      void event() => events.add({
        'eventType': 'chat.group.read',
        'data': {'groupId': 'current'},
      });
      event();
      await Future<void>.delayed(Duration.zero);
      expect(requests, 2);
      event();
      event();
      await Future<void>.delayed(Duration.zero);
      expect(requests, 2);
      pending.complete(grant('one', group: true));
      await Future<void>.delayed(Duration.zero);
      expect(requests, 3);
      expect(player.activeId, isNull);
    },
  );
  for (final group in [false, true]) {
    test(
      'other direct conversation events preserve ${group ? "group" : "direct"} voice',
      () async {
        final output = Output();
        final events = StreamController<Map<String, dynamic>>.broadcast();
        final repo = MessagingRepository(
          account: 'me',
          call: (_, p) async => grant(p['messageId'] as String, group: group),
        );
        final player = ChatVoicePlayback(
          output: output,
          events: events.stream,
          loadFile: (_, _, _, _) async => File('/fixture.m4a'),
        );
        addTearDown(player.dispose);
        addTearDown(events.close);
        await player.toggle(
          repo,
          'one',
          group: group,
          groupId: group ? 'group' : null,
          conversationId: 'current',
        );
        final stops = output.stops;
        for (final type in [
          'chat.settings.changed',
          'chat.relationship.changed',
        ]) {
          events.add({
            'eventType': type,
            'data': {'conversationId': 'other'},
          });
        }
        await Future<void>.delayed(Duration.zero);
        expect(player.activeId, 'one');
        expect(output.stops, stops);
        events.add({
          'eventType': group
              ? 'chat.group.changed'
              : 'chat.relationship.changed',
          'data': group ? {'groupId': 'group'} : {'conversationId': 'current'},
        });
        await Future<void>.delayed(Duration.zero);
        expect(player.activeId, isNull);
        expect(output.stops, stops + 1);
      },
    );
  }
  for (final group in [false, true]) {
    test(
      'unrelated group events do not interrupt ${group ? "group" : "direct"} audio',
      () async {
        final output = Output();
        final events = StreamController<Map<String, dynamic>>.broadcast();
        final repo = MessagingRepository(
          account: 'me',
          call: (_, p) async => grant(p['messageId'] as String, group: group),
        );
        final player = ChatVoicePlayback(
          output: output,
          events: events.stream,
          loadFile: (_, _, _, _) async => File('/fixture.m4a'),
        );
        addTearDown(player.dispose);
        addTearDown(events.close);
        await player.toggle(
          repo,
          'one',
          group: group,
          groupId: group ? 'current' : null,
        );
        for (final type in ['chat.group.read', 'chat.group.changed']) {
          events.add({
            'eventType': type,
            'data': {'groupId': 'other'},
          });
        }
        await Future<void>.delayed(Duration.zero);
        expect(player.activeId, 'one');
        events.add({
          'eventType': group ? 'chat.group.changed' : 'chat.settings.changed',
          'data': group ? {'groupId': 'current'} : {},
        });
        await Future<void>.delayed(Duration.zero);
        expect(player.activeId, isNull);
      },
    );
  }
}
