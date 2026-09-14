import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_forwarder.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

const id = '11111111-1111-4111-8111-111111111111';
const hash = '039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81';

class _File implements File {
  _File({this.corrupt = false});
  final bool corrupt;
  @override
  Future<int> length() async => 3;
  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      Stream.value(corrupt ? [3, 2, 1] : [1, 2, 3]);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

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
          loadFile: (_) async => _File(),
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
        await forwarder.acknowledgeQueued();
        expect(uploader.acks, 1);
        deny = true;
        await expectLater(forwarder.prepare(), throwsStateError);
        expect(processes, 2);
      },
    );
  }
  test('corrupted cached video is rejected before uploading', () async {
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
      loadFile: (_) async => _File(corrupt: true),
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
        return _File();
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
}
