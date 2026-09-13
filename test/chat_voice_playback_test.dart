import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_playback.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';

class Output implements ChatVoiceOutput {
  final plays = <String>[];
  int stops = 0;
  final done = StreamController<void>.broadcast();
  @override
  Stream<void> get completed => done.stream;
  @override
  Future<void> play(String path) async {
    plays.add(path);
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() => done.close();
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
}
