import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_draft_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_image_uploader.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_image_send_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_video_send_page.dart';

import 'chat_file_send_recovery_test.dart' show Drafts, Preview;
import 'direct_chat_controller_test.dart' show MemoryOutbox;

void main() {
  for (final video in [false, true]) {
    testWidgets(
      'invalid session hides media and disables mutations: video=$video',
      (tester) async {
        var calls = 0;
        final repo = MessagingRepository(
          account: 'me',
          call: (_, _) async {
            calls++;
            return {};
          },
        );
        final chat = DirectChatController(
          peer: 'peer',
          outbox: MemoryOutbox(),
          repository: repo,
        );
        addTearDown(chat.dispose);
        final drafts = Drafts();
        final file = File('/private-video.mp4');
        final draft = ChatFileDraft(
          '33333333-3333-4333-8333-333333333333',
          file,
          'private-video.mp4',
          1,
          'a' * 64,
        );
        final pending = Completer<ChatImageUploader>();
        await tester.pumpWidget(
          MaterialApp(
            home: video
                ? ChatVideoSendPage(
                    file: file,
                    fileName: 'private-video.mp4',
                    chat: chat,
                    draft: draft,
                    drafts: drafts,
                    createPreview: Preview.new,
                  )
                : ChatImageSendPage(
                    bytes: base64Decode(
                      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
                    ),
                    chat: chat,
                    draft: draft,
                    drafts: drafts,
                    createUploader: () => pending.future,
                  ),
          ),
        );
        await tester.pumpAndSettle();
        if (!video) {
          expect(
            find.byWidgetPredicate(
              (widget) => widget is Image && widget.image is! AssetImage,
            ),
            findsOneWidget,
          );
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
          await tester.pump();
        } else {
          expect(find.text('private-video.mp4'), findsOneWidget);
        }
        SecureSessionStore.changes.add(null);
        await tester.pump();
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (widget) => widget is Image && widget.image is! AssetImage,
          ),
          findsNothing,
        );
        expect(find.text('private-video.mp4'), findsNothing);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
        if (!video) {
          pending.complete(
            ChatImageUploader(repository: repo, checkSession: () async {}),
          );
          await tester.pumpAndSettle();
        }
        expect(calls, 0);
        expect(drafts.removed, isEmpty);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
    );
  }
}
