import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_details_page.dart';

class PendingDownload extends ChatFileDownloader {
  PendingDownload(MessagingRepository repository)
    : super(repository: repository, checkSession: () async {});
  Completer<File>? pending;
  int downloads = 0;
  bool released = false;
  bool local = false;
  @override
  bool get lastReadWasLocal => local;
  @override
  Future<File> download(
    ChatFileReference ref, {
    void Function(int, int)? onProgress,
  }) {
    downloads++;
    pending = Completer<File>();
    onProgress?.call(1, 2);
    return pending!.future;
  }

  @override
  void cancel() {
    if (pending?.isCompleted == false) {
      pending!.completeError(StateError('cancelled'));
    }
  }

  @override
  Future<void> dispose() async {
    released = true;
    await super.dispose();
  }
}

void main() {
  for (final stage in ['opening', 'reading', 'complete']) {
    testWidgets('session change clears file details during $stage', (
      tester,
    ) async {
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) async => {},
      );
      final download = PendingDownload(repo);
      final opening = Completer<ChatFileDownloader>();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatFileDetailsPage(
            repository: repo,
            openDownloader: (_) =>
                stage == 'opening' ? opening.future : Future.value(download),
            reference: const ChatFileReference(
              messageId: 'id',
              assetId: 'asset',
              fileName: 'private.txt',
              size: 2,
              sha256: 'test',
            ),
          ),
        ),
      );
      await tester.tap(find.text('读取文件'));
      await tester.pump();
      if (stage == 'complete') {
        download.pending!.complete(File('synthetic-file'));
        await tester.pump();
      }
      SecureSessionStore.changes.add(null);
      await tester.pump();
      await tester.pump();
      if (stage == 'opening') {
        opening.complete(download);
        await tester.pump();
        expect(download.downloads, 0);
        expect(download.released, true);
      }
      expect(find.text('private.txt'), findsNothing);
      expect(find.text('登录状态已变化，请重新进入会话'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('下载完成，文件校验通过'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }
  for (final completed in [false, true]) {
    for (final local in [false, true]) {
      testWidgets(
        'deletion removes file actions, completed=$completed local=$local',
        (tester) async {
          final repo = MessagingRepository(
            account: 'synthetic',
            call: (_, _) async => {},
          );
          final download = PendingDownload(repo)..local = local;
          await tester.pumpWidget(
            MaterialApp(
              home: ChatFileDetailsPage(
                repository: repo,
                openDownloader: (_) async => download,
                reference: const ChatFileReference(
                  messageId: 'id',
                  assetId: 'asset',
                  fileName: 'test.txt',
                  size: 2,
                  sha256: 'test',
                ),
              ),
            ),
          );
          await tester.tap(find.text('读取文件'));
          await tester.pump();
          if (completed) {
            download.pending!.complete(File('synthetic-file'));
            await tester.pump();
            expect(
              find.text(local ? '已从本地读取，文件校验通过' : '下载完成，文件校验通过'),
              findsOneWidget,
            );
          }
          await const ChatMediaDeletion(
            'other-account',
            false,
            'id',
          ).dispatch();
          await const ChatMediaDeletion('synthetic', true, 'id').dispatch();
          await tester.pump();
          expect(find.text('内容已移除'), findsNothing);
          await const ChatMediaDeletion('synthetic', false, 'id').dispatch();
          await tester.pump();
          expect(find.text('内容已移除'), findsOneWidget);
          expect(find.text('test.txt'), findsNothing);
          expect(find.text('下载完成，文件校验通过'), findsNothing);
          expect(find.text('已从本地读取，文件校验通过'), findsNothing);
          expect(find.byType(FilledButton), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          expect(download.downloads, 1);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'download cancellation permits retry and page disposal releases download',
    (tester) async {
      final repo = MessagingRepository(
        account: 'synthetic',
        call: (_, _) async => {},
      );
      final download = PendingDownload(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatFileDetailsPage(
            repository: repo,
            openDownloader: (_) async => download,
            reference: const ChatFileReference(
              messageId: 'id',
              assetId: 'asset',
              fileName: '测试文件.pdf',
              size: 2,
              sha256: 'test',
            ),
          ),
        ),
      );
      expect(download.downloads, 0);
      await tester.tap(find.text('读取文件'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('取消读取'));
      await tester.pump();
      expect(find.text('读取文件'), findsOneWidget);
      await tester.tap(find.text('读取文件'));
      await tester.pump();
      expect(download.downloads, 2);
      download.pending!.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('重试读取'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(download.released, true);
      expect(tester.takeException(), isNull);
    },
  );
}
