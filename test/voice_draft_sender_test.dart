import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/voice_draft_sender.dart';
import 'package:kingclub/src/features/messaging/data/voice_draft_store.dart';
import 'package:kingclub/src/features/messaging/data/voice_capture.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_uploader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, ack;

class Upload extends ChatVoiceUploader {
  Upload(MessagingRepository repo)
    : super(repository: repo, checkSession: () async {}, dio: Dio());
  bool fail = false, acknowledged = false;
  Completer<void>? paused, started;
  @override
  Future<UploadedChatVoice> upload(
    Uint8List input, {
    void Function(int, int)? onProgress,
  }) async {
    started?.complete();
    if (paused != null) await paused!.future;
    if (fail) throw StateError('upload failed');
    return const UploadedChatVoice(
      '12345678-1234-1234-1234-123456789012',
      2000,
      'fingerprint',
      'request',
    );
  }

  @override
  Future<void> acknowledgeQueued(UploadedChatVoice voice) async {
    acknowledged = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final confirmed in [false, true]) {
    test(
      'leftover queued voice draft does not upload again: $confirmed',
      () async {
        final root = await Directory.systemTemp.createTemp('voice-owned-');
        addTearDown(() => root.delete(recursive: true));
        final store = VoiceDraftStore(root: root, account: 'me');
        final path = await store.allocate();
        await File(path).writeAsBytes([1, 2, 3]);
        final queue = MemoryOutbox();
        var calls = 0;
        final repo = MessagingRepository(
          account: 'me',
          call: (_, params) async {
            calls++;
            if (!confirmed) throw const AuthFailure('NETWORK_ERROR', 'offline');
            return {
              'message': {
                ...ack(params),
                'messageType': 'voice',
                'voiceAssetId': params['assetId'],
                'voiceDurationMs': 2000,
                'text': '[语音]',
              },
            };
          },
        );
        final chat = DirectChatController(
          repository: repo,
          peer: 'peer',
          outbox: queue,
        );
        addTearDown(chat.dispose);
        await chat.sendVoice(
          '12345678-1234-1234-1234-123456789012',
          2000,
          clientMessageId: store.messageId(path),
        );
        expect(chat.messages, hasLength(1));
        final sender = VoiceDraftSender(
          currentStore: () async => store,
          openUploader: (_) async => throw StateError('duplicate upload'),
        );
        addTearDown(sender.dispose);
        await sender.send(chat, VoiceDraft(path, const Duration(seconds: 2)));
        expect(calls, 1);
        expect(chat.messages, hasLength(1));
        expect(queue.items, confirmed ? isEmpty : hasLength(1));
        expect(await File(path).exists(), false);
      },
    );
  }
  for (final stage in ['upload', 'queue', 'network']) {
    test(
      'draft survives $stage failure until durable queue takes ownership',
      () async {
        final root = await Directory.systemTemp.createTemp('voice-sender-');
        addTearDown(() => root.delete(recursive: true));
        final store = VoiceDraftStore(root: root, account: 'me');
        final path = await store.allocate();
        await File(path).writeAsBytes([1, 2, 3]);
        final repo = MessagingRepository(
          account: 'me',
          call: (_, _) async =>
              throw const AuthFailure('NETWORK_ERROR', 'offline'),
        );
        final upload = Upload(repo)..fail = stage == 'upload';
        final queue = MemoryOutbox()..failWrite = stage == 'queue';
        final chat = DirectChatController(
          repository: repo,
          peer: 'peer',
          outbox: queue,
        );
        final sender = VoiceDraftSender(
          currentStore: () async => store,
          openUploader: (_) async => upload,
        );
        addTearDown(sender.dispose);
        addTearDown(chat.dispose);
        final future = sender.send(
          chat,
          VoiceDraft(path, const Duration(seconds: 2)),
        );
        if (stage == 'network') {
          await future;
          expect(await File(path).exists(), false);
          expect(upload.acknowledged, true);
          expect(queue.items.length, 1);
          expect(queue.items.keys.single, store.messageId(path));
          expect(chat.messages.single['status'], 'queued');
        } else {
          await expectLater(future, throwsStateError);
          expect(await File(path).exists(), true);
          expect(upload.acknowledged, false);
          expect(queue.items, isEmpty);
        }
      },
    );
  }
  test('closing conversation while upload completes preserves draft and prevents queueing', () async {
    final root = await Directory.systemTemp.createTemp('voice-sender-close-');
    addTearDown(() => root.delete(recursive: true));
    final store = VoiceDraftStore(root: root, account: 'me');
    final path = await store.allocate();
    await File(path).writeAsBytes([1, 2, 3]);
    final repo = MessagingRepository(
      account: 'me',
      call: (_, _) async => throw StateError('must not send'),
    );
    final upload = Upload(repo)
      ..paused = Completer<void>()
      ..started = Completer<void>();
    final queue = MemoryOutbox();
    final chat = DirectChatController(
      repository: repo,
      peer: 'peer',
      outbox: queue,
    );
    final sender = VoiceDraftSender(
      currentStore: () async => store,
      openUploader: (_) async => upload,
    );
    addTearDown(chat.dispose);
    final sending = sender.send(
      chat,
      VoiceDraft(path, const Duration(seconds: 2)),
    );
    final rejected = expectLater(sending, throwsStateError);
    await upload.started!.future;
    sender.dispose();
    upload.paused!.complete();
    await rejected;
    expect(queue.items, isEmpty);
    expect(upload.acknowledged, false);
    expect(await File(path).exists(), true);
  });
  test('foreign draft is rejected before opening upload', () async {
    final root = await Directory.systemTemp.createTemp('voice-sender-scope-');
    addTearDown(() => root.delete(recursive: true));
    final own = VoiceDraftStore(root: root, account: 'me'),
        other = VoiceDraftStore(root: root, account: 'other');
    final path = await other.allocate();
    await File(path).writeAsBytes([1]);
    var opened = false;
    final sender = VoiceDraftSender(
      currentStore: () async => own,
      openUploader: (_) async {
        opened = true;
        throw StateError('must not open');
      },
    );
    final chat = DirectChatController(
      repository: MessagingRepository(account: 'me', call: (_, _) async => {}),
      peer: 'peer',
      outbox: MemoryOutbox(),
    );
    addTearDown(sender.dispose);
    addTearDown(chat.dispose);
    await expectLater(
      sender.send(chat, VoiceDraft(path, Duration.zero)),
      throwsStateError,
    );
    expect(opened, false);
    expect(await File(path).exists(), true);
  });
}
