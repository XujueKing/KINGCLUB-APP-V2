import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_uploader.dart';
import 'package:kingclub/src/features/messaging/data/chat_session_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_image_send_page.dart';

class RetainingStore extends MediaCache {
  final keys = <String>[];
  @override
  Future<File> importBytes(
    Uint8List bytes, {
    required String scope,
    required String contentKey,
    required MediaKind kind,
  }) async {
    expect(scope, 'member:me');
    expect(bytes, [9, 8, 7]);
    keys.add(contentKey);
    if (keys.length == 1) throw StateError('disk full');
    return File('retained');
  }
}

class Upload extends ChatImageUploader {
  Upload(MessagingRepository repo)
    : super(repository: repo, checkSession: () async {});
  int calls = 0;
  @override
  Future<UploadedChatImage> upload(
    Uint8List input, {
    void Function(int, int)? onProgress,
  }) async {
    calls++;
    return UploadedChatImage(
      'asset',
      100,
      100,
      'fingerprint',
      'request',
      sourceBytes: Uint8List.fromList([9, 8, 7]),
    );
  }

  @override
  Future<void> acknowledgeQueued(UploadedChatImage image) async {}
}

class Chat extends ChangeNotifier implements ChatSessionController {
  Chat(this.messaging);
  @override
  final MessagingRepository messaging;
  String? sentId;
  @override
  Future<void> sendImage(
    String assetId, {
    VoidCallback? onQueued,
    String? clientMessageId,
  }) async {
    sentId = clientMessageId;
    onQueued?.call();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected operation');
}

void main() {
  testWidgets('photo waits for retention and retries without another upload', (
    tester,
  ) async {
    final bytes = await tester.runAsync(
      () => File('assets/legacy/storage/wine_flip.png').readAsBytes(),
    );
    final repo = MessagingRepository(account: 'me', call: (_, _) async => {});
    final chat = Chat(repo);
    final upload = Upload(repo);
    final store = RetainingStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ChatImageSendPage(
          bytes: bytes!,
          chat: chat,
          mediaStore: store,
          createUploader: () async => upload,
        ),
      ),
    );
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(chat.sentId, isNull);
    expect(store.keys, hasLength(1));
    await tester.tap(find.text('发送'));
    await tester.pumpAndSettle();
    expect(chat.sentId, isNotNull);
    expect(store.keys, [
      'chat-image-sent:${chat.sentId}',
      'chat-image-sent:${chat.sentId}',
    ]);
    expect(upload.calls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
