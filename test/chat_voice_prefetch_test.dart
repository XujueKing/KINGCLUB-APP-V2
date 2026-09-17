import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_prefetch.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';

const message = '12345678-1234-1234-1234-123456789012';
const asset = '22345678-1234-1234-1234-123456789012';
const fileId = '32345678-1234-1234-1234-123456789012';
final rows = <Map<String, dynamic>>[
  {
    'messageId': message,
    'voiceAssetId': asset,
    'sender': 'peer',
    'messageType': 'voice',
  },
];
Map<String, dynamic> grant() => {
  'messageId': message,
  'voice': {
    'fileId': fileId,
    'durationMs': 3000,
    'contentType': 'audio/mp4',
    'path': '/kingclub/chat-voice/$message',
    'headers': {'authorization': 'Bearer fixture'},
  },
};

class Store extends MediaCache {
  final download = Completer<File>();
  int downloads = 0;
  final retained = <String>[];
  @override
  Future<File> cached({
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    if (retained.contains(contentKey)) return File('saved.m4a');
    throw StateError('missing');
  }

  @override
  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) {
    expect(scope, 'member:me');
    expect(kind, MediaKind.audio);
    expect(contentKey, 'chat-voice-transfer:false:$message');
    expect(headers?['authorization'], 'Bearer fixture');
    downloads++;
    return download.future;
  }

  @override
  Future<File> importFile(
    File source, {
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    retained.add(contentKey);
    return source;
  }
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

class DiskVoices extends MediaCache {
  DiskVoices(Directory root) : super(directory: () async => root);
  int downloads = 0;
  @override
  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) async {
    downloads++;
    return importBytes(
      Uint8List.fromList([1, 2, 3]),
      scope: scope,
      contentKey: contentKey!,
      kind: kind,
    );
  }
}

void main() {
  for (final group in [false, true]) {
    test('missing sent voice survives disk reopen group=$group', () async {
      final root = await Directory.systemTemp.createTemp('voice-backfill-');
      addTearDown(() => root.delete(recursive: true));
      final media = DiskVoices(root);
      var calls = 0;
      final worker = ChatVoicePrefetch(
        MessagingRepository(
          account: 'me',
          call: (method, _) async {
            expect(method, group ? 'K260913000640' : 'K260913000638');
            calls++;
            final result = grant();
            (result['voice'] as Map)['path'] =
                '/kingclub/${group ? 'group-chat-voice' : 'chat-voice'}/$message';
            return result;
          },
        ),
        group: group,
        media: media,
      );
      addTearDown(worker.dispose);
      final sent = [
        {...rows.single, 'sender': 'me'},
      ];
      worker.update(sent);
      await worker.idle;
      expect(worker.hasFailures, false);
      final reopened = MediaCache(directory: () async => root);
      final saved = await reopened.cached(
        scope: 'member:me',
        contentKey: 'chat-voice-asset:$asset',
        kind: MediaKind.audio,
      );
      expect(await saved.readAsBytes(), [1, 2, 3]);
      worker.update(sent);
      await worker.idle;
      expect(calls, 2);
      expect(media.downloads, 1);
    });
  }
  test(
    'deletion waits for late transfer and prevents retention or retry',
    () async {
      final store = Store();
      final worker = ChatVoicePrefetch(
        MessagingRepository(account: 'me', call: (_, _) async => grant()),
        group: false,
        media: store,
      );
      addTearDown(worker.dispose);
      worker.update(rows);
      await settle();
      expect(store.downloads, 1);
      var finished = false;
      final deletion = const ChatMediaDeletion(
        'me',
        false,
        message,
      ).dispatch().then((_) => finished = true);
      await settle();
      expect(finished, false);
      store.download.complete(File('late.m4a'));
      await deletion;
      expect(store.retained, isEmpty);
      worker.update(rows);
      await worker.idle;
      expect(store.downloads, 1);
      expect(worker.hasFailures, false);
    },
  );
  for (final mode in ['success', 'revoked', 'session']) {
    test('received voice prefetch $mode', () async {
      final store = Store();
      var calls = 0;
      final worker = ChatVoicePrefetch(
        MessagingRepository(
          account: 'me',
          call: (_, _) async {
            calls++;
            if (calls == 2 && mode == 'revoked') throw StateError('removed');
            return grant();
          },
        ),
        group: false,
        media: store,
      );
      addTearDown(worker.dispose);
      worker.update(rows);
      await settle();
      worker.update(rows);
      expect(store.downloads, 1);
      if (mode == 'session') {
        SecureSessionStore.changes.add(null);
        await settle();
      }
      store.download.complete(File('downloaded.m4a'));
      await settle();
      if (mode == 'success') {
        expect(store.retained, ['chat-voice-asset:$asset']);
        expect(calls, 2);
      } else {
        expect(store.retained, isEmpty);
        expect(calls, mode == 'session' ? 1 : 2);
      }
      worker.update(rows);
      await settle();
      expect(store.downloads, 1);
    });
  }
  test('cached own and non-voice messages do not trigger downloads', () async {
    final store = Store();
    store.retained.add('chat-voice-asset:$asset');
    final worker = ChatVoicePrefetch(
      MessagingRepository(
        account: 'me',
        call: (_, _) async => throw StateError('unexpected'),
      ),
      group: false,
      media: store,
    );
    addTearDown(worker.dispose);
    worker.update([
      {...rows.single, 'sender': 'me'},
      {...rows.single, 'messageType': 'image'},
    ]);
    await settle();
    expect(store.downloads, 0);
  });
}
