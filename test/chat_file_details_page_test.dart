import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_details_page.dart';

class PendingDownload extends ChatFileDownloader {
  PendingDownload(MessagingRepository repository)
    : super(repository: repository, checkSession: () async {});
  Completer<File>? pending;
  int downloads = 0;
  bool released = false;
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
      await tester.tap(find.text('下载文件'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('取消下载'));
      await tester.pump();
      expect(find.text('下载文件'), findsOneWidget);
      await tester.tap(find.text('下载文件'));
      await tester.pump();
      expect(download.downloads, 2);
      download.pending!.completeError(StateError('offline'));
      await tester.pump();
      expect(find.text('重新下载'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(download.released, true);
      expect(tester.takeException(), isNull);
    },
  );
}
