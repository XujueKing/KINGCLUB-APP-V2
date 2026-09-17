import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_image_send_page.dart';

import 'chat_image_send_retention_test.dart' show Chat, Upload, RetainingStore;

class SlowChat extends Chat {
  SlowChat(super.repository);
  final network = Completer<void>();
  @override
  Future<void> sendImage(
    String assetId, {
    VoidCallback? onQueued,
    String? clientMessageId,
  }) async {
    await super.sendImage(
      assetId,
      onQueued: onQueued,
      clientMessageId: clientMessageId,
    );
    await network.future;
  }
}

void main() {
  testWidgets('image composer returns before remote acknowledgement', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = (await tester.runAsync(
      () => File('assets/legacy/storage/wine_flip.png').readAsBytes(),
    ))!;
    final repo = MessagingRepository(account: 'me', call: (_, _) async => {});
    final chat = SlowChat(repo);
    final media = RetainingStore()
      ..keys.add('skip simulated first disk failure');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatImageSendPage(
                    bytes: bytes,
                    chat: chat,
                    mediaStore: media,
                    createUploader: () async => Upload(repo),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(
      chat.sentId,
      isNotNull,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join('|'),
    );
    expect(chat.network.isCompleted, false);
    expect(find.byType(ChatImageSendPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
    chat.network.completeError(StateError('network failed after queue'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
