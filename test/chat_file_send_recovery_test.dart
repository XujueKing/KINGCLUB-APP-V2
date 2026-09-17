import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_draft_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_video.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_send_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_image_send_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_send_page.dart';
import 'package:video_player/video_player.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack;

class Drafts extends ChatFileDraftStore {
  Drafts()
    : super(account: 'me', target: 'direct:peer', checkSession: () async {});
  final removed = <String>[];
  @override
  Future<void> remove(String id) async {
    removed.add(id);
  }
}

class Preview extends VideoPlayerController {
  Preview(super.file) : super.file();
  @override
  Future<void> initialize() async {}
  @override
  // No platform player is created by this double.
  // ignore: must_call_super
  Future<void> dispose() async {}
}

// This suite verifies composer idempotency; filesystem persistence has its
// own MediaCache tests. Do not invoke path_provider from a widget fake clock.
class RetainingMedia extends MediaCache {
  final keys = <String>[];
  @override
  Future<File> importBytes(
    Uint8List bytes, {
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    expect(scope, 'member:me');
    expect(kind, MediaKind.image);
    expect(bytes, isNotEmpty);
    keys.add(contentKey);
    return File('retained-image');
  }

  @override
  Future<File> importFile(
    File source, {
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    expect(scope, 'member:me');
    expect(kind, MediaKind.video);
    expect(source.path, '/not-needed-for-already-queued.bin');
    keys.add(contentKey);
    return File('retained-video');
  }
}

void main() {
  for (final kind in ['file', 'image', 'video']) {
    for (final confirmed in [false, true]) {
      testWidgets(
        '$kind draft already owned by chat skips upload: $confirmed',
        (tester) async {
          const id = '33333333-3333-4333-8333-333333333333';
          const asset = '12345678-1234-1234-1234-123456789012';
          var calls = 0;
          final queue = MemoryOutbox();
          final chat = DirectChatController(
            peer: 'peer',
            outbox: queue,
            repository: MessagingRepository(
              account: 'me',
              call: (_, params) async {
                calls++;
                if (!confirmed) {
                  throw const AuthFailure('NETWORK_ERROR', 'offline');
                }
                return {
                  'message': {
                    ...ack(params),
                    'messageType': kind,
                    'imageAssetId': asset,
                    'videoAssetId': asset,
                    'videoDurationMs': 1000,
                    'videoWidth': 640,
                    'videoHeight': 480,
                    'videoHasAudio': true,
                    'fileAssetId': asset,
                    'fileName': 'fixture.bin',
                    'fileSize': 2,
                    'fileSha256': 'a' * 64,
                    'text': '[文件]',
                  },
                };
              },
            ),
          );
          addTearDown(chat.dispose);
          if (kind == 'image') {
            await chat.sendImage(asset, clientMessageId: id);
          } else if (kind == 'video') {
            await chat.sendVideo(
              ChatVideo(
                assetId: asset,
                durationMs: 1000,
                width: 640,
                height: 480,
                hasAudio: true,
              ),
              clientMessageId: id,
            );
          } else {
            await chat.sendFile(
              asset,
              'fixture.bin',
              2,
              'a' * 64,
              clientMessageId: id,
            );
          }
          final drafts = Drafts();
          final media = RetainingMedia();
          final file = File('/not-needed-for-already-queued.bin');
          final draft = ChatFileDraft(id, file, 'fixture.bin', 2, 'a' * 64);
          bool? result;
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => kind == 'image'
                            ? ChatImageSendPage(
                                mediaStore: media,
                                bytes: base64Decode(
                                  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
                                ),
                                chat: chat,
                                drafts: drafts,
                                draft: draft,
                              )
                            : kind == 'video'
                            ? ChatVideoSendPage(
                                mediaStore: media,
                                file: file,
                                fileName: 'fixture.mp4',
                                chat: chat,
                                drafts: drafts,
                                draft: draft,
                                createPreview: Preview.new,
                                createUploader: () =>
                                    throw StateError('must not upload again'),
                              )
                            : ChatFileSendPage(
                                file: file,
                                fileName: 'fixture.bin',
                                chat: chat,
                                drafts: drafts,
                                draft: ChatFileDraft(
                                  id,
                                  file,
                                  'fixture.bin',
                                  2,
                                  'a' * 64,
                                ),
                              ),
                      ),
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          );
          await tester.tap(find.text('open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('发送'));
          await tester.pumpAndSettle();
          expect(result, true);
          expect(
            media.keys,
            kind == 'file' ? isEmpty : ['chat-$kind-sent:$id'],
          );
          expect(drafts.removed, [id]);
          expect(calls, 1);
          expect(chat.messages, hasLength(1));
          expect(queue.items, confirmed ? isEmpty : hasLength(1));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
