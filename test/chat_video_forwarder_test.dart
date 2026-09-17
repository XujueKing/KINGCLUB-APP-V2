import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_forwarder.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';

const id = '11111111-1111-4111-8111-111111111111';
const hash = '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';

class _Uploader extends ChatFileUploader {
  _Uploader(MessagingRepository repo)
    : super(repository: repo, checkSession: () async {});
  int uploads = 0, acks = 0;
  @override
  Future<UploadedChatFile> upload(
    File file, {
    required String fileName,
    void Function(int, int)? onProgress,
  }) async {
    uploads++;
    return const UploadedChatFile(id, 'video.mp4', 3, hash, 'f', 'r');
  }

  @override
  Future<void> acknowledgeQueued(UploadedChatFile file) async {
    acks++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final group in [false, true]) {
    test(
      'video source ${group ? 'group' : 'direct'} rechecks access and retries processing without reupload',
      () async {
        final dir = await Directory.systemTemp.createTemp('forward-video-');
        addTearDown(() => dir.delete(recursive: true));
        final source = await File('${dir.path}/source.mp4')
            .writeAsBytes([1, 2, 3]);
        final mediaRoot = Directory('${dir.path}/media');
        final media = MediaCache(directory: () async => mediaRoot);
        var grants = 0, processes = 0, deny = false;
        final repo = MessagingRepository(
          account: 'me',
          call: (api, p) async {
            if (api == (group ? 'K260915000668' : 'K260915000667')) {
              grants++;
              if (deny) throw StateError('recalled');
              return {
                'messageId': id,
                'video': {
                  'fileId': id,
                  'size': 3,
                  'sha256': hash,
                  'path':
                      '/kingclub/${group ? 'group-chat-video' : 'chat-video'}/$id/video',
                  'headers': {'authorization': 'Bearer fixture'},
                },
              };
            }
            expect(api, 'K260915000669');
            expect(p, {'sourceAssetId': id});
            if (++processes == 1) {
              throw StateError('temporary processing failure');
            }
            return {
              'assetId': id,
              'status': 'ready',
              'width': 320,
              'height': 240,
              'durationMs': 2000,
              'hasAudio': true,
            };
          },
        );
        final uploader = _Uploader(repo);
        final forwarder = ChatVideoForwarder(
          repository: repo,
          messageId: id,
          group: group,
          loadFile: (_) async => source,
          mediaStore: media,
          openUploader: () async => uploader,
        );
        addTearDown(forwarder.dispose);
        await expectLater(forwarder.prepare(), throwsStateError);
        expect(uploader.uploads, 1);
        final result = await forwarder.prepare();
        expect(result.assetId, id);
        expect(result.hasAudio, true);
        expect(uploader.uploads, 1);
        expect(processes, 2);
        expect(grants, 4);
        expect(await mediaRoot.exists(), false);
        await forwarder.acknowledgeQueued(clientMessageId: 'new-client');
        await source.delete();
        final reopened = MediaCache(directory: () async => mediaRoot);
        final local = await reopened.cached(
          scope: 'member:me',
          contentKey: 'chat-video-sent:new-client',
          kind: MediaKind.video,
        );
        expect(await local.readAsBytes(), [1, 2, 3]);
        await ChatMediaCleanup(media: reopened).remove(
          account: 'me',
          group: group,
          message: {
            'sender': 'me',
            'messageType': 'video',
            'messageId': 'new-message',
            'clientMessageId': 'new-client',
          },
        );
        expect(await local.exists(), false);
        expect(uploader.acks, 1);
        deny = true;
        await expectLater(forwarder.prepare(), throwsStateError);
        expect(processes, 2);
      },
    );
  }
  test('corrupted cached video is rejected before uploading', () async {
    final dir = await Directory.systemTemp.createTemp('forward-corrupt-');
    addTearDown(() => dir.delete(recursive: true));
    final source = await File('${dir.path}/source.mp4').writeAsBytes([3, 2, 1]);
    final repo = MessagingRepository(
      account: 'me',
      call: (_, _) async => {
        'messageId': id,
        'video': {
          'fileId': id,
          'size': 3,
          'sha256': hash,
          'path': '/kingclub/chat-video/$id/video',
          'headers': {'authorization': 'Bearer fixture'},
        },
      },
    );
    var opened = 0;
    final f = ChatVideoForwarder(
      repository: repo,
      messageId: id,
      loadFile: (_) async => source,
      openUploader: () async {
        opened++;
        return _Uploader(repo);
      },
    );
    addTearDown(f.dispose);
    await expectLater(f.prepare(), throwsStateError);
    expect(opened, 0);
  });
  test('logout while fetching grant never opens upload', () async {
    final pending = Completer<Map<String, dynamic>>();
    var loaded = 0;
    final repo = MessagingRepository(
      account: 'me',
      call: (_, _) => pending.future,
    );
    final f = ChatVideoForwarder(
      repository: repo,
      messageId: id,
      loadFile: (_) async {
        loaded++;
        throw StateError('File loading must not start after logout');
      },
    );
    addTearDown(f.dispose);
    final result = expectLater(f.prepare(), throwsStateError);
    SecureSessionStore.changes.add(null);
    await Future<void>.delayed(Duration.zero);
    pending.complete({
      'messageId': id,
      'video': {
        'fileId': id,
        'size': 3,
        'sha256': hash,
        'path': '/kingclub/chat-video/$id/video',
        'headers': {'authorization': 'Bearer fixture'},
      },
    });
    await result;
    expect(loaded, 0);
  });
  test('cancel during file load never opens uploader', () async {
    final dir = await Directory.systemTemp.createTemp('forward-cancel-');
    addTearDown(() => dir.delete(recursive: true));
    final source = await File('${dir.path}/source.mp4').writeAsBytes([1, 2, 3]);
    final loaded = Completer<void>(), release = Completer<File>();
    var uploadsOpened = 0;
    final repo = MessagingRepository(
      account: 'me',
      call: (_, _) async => {
        'messageId': id,
        'video': {
          'fileId': id,
          'size': 3,
          'sha256': hash,
          'path': '/kingclub/chat-video/$id/video',
          'headers': {'authorization': 'Bearer fixture'},
        },
      },
    );
    final forwarder = ChatVideoForwarder(
      repository: repo,
      messageId: id,
      loadFile: (_) {
        loaded.complete();
        return release.future;
      },
      openUploader: () async {
        uploadsOpened++;
        return _Uploader(repo);
      },
    );
    addTearDown(forwarder.dispose);
    final result = expectLater(forwarder.prepare(), throwsStateError);
    await loaded.future;
    forwarder.dispose();
    release.complete(source);
    await result;
    expect(uploadsOpened, 0);
  });
}
