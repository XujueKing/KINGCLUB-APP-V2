import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_forwarder.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class Source extends ChatFileDownloader {
  Source(this.file, MessagingRepository repo)
    : super(repository: repo, checkSession: () async {});
  final File file;
  int downloads = 0;
  bool cleaned = false;
  @override
  Future<File> download(
    ChatFileReference ref, {
    void Function(int, int)? onProgress,
  }) async {
    downloads++;
    return file;
  }

  @override
  Future<void> dispose() async {
    cleaned = true;
    if (await file.exists()) await file.delete();
    await super.dispose();
  }
}

class Destination extends ChatFileUploader {
  Destination(this.asset, MessagingRepository repo)
    : super(repository: repo, checkSession: () async {});
  final UploadedChatFile asset;
  int uploads = 0;
  int retained = 0, acknowledged = 0;
  Completer<void>? wait;
  Completer<void>? retainWait;
  @override
  Future<void> retainQueuedSource(File source, UploadedChatFile file) async {
    expect(await source.readAsBytes(), [1, 2, 3]);
    expect(file, asset);
    retained++;
    if (retainWait != null) await retainWait!.future;
    expect(await source.exists(), true);
  }

  @override
  Future<void> acknowledgeQueued(UploadedChatFile file) async {
    expect(retained, 1);
    acknowledged++;
  }

  @override
  Future<UploadedChatFile> upload(
    File input, {
    required String fileName,
    void Function(int, int)? onProgress,
  }) async {
    uploads++;
    expect(await input.readAsBytes(), [1, 2, 3]);
    expect(fileName, 'test.bin');
    if (wait != null) await wait!.future;
    return asset;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in [
    'success',
    'cancel',
    'retention-cancel',
    'mismatch',
    'session',
  ]) {
    test(
      'file copy $mode cleans temporary source and verifies digest',
      () async {
        final dir = await Directory.systemTemp.createTemp('file-forward-');
        addTearDown(() => dir.delete(recursive: true));
        final file = await File('${dir.path}/source').writeAsBytes([1, 2, 3]);
        final repo = MessagingRepository(
          account: 'me',
          call: (_, p) async => {},
        );
        final ref = ChatFileReference(
          messageId: 'm',
          assetId: 'a',
          fileName: 'test.bin',
          size: 3,
          sha256: 'a' * 64,
        );
        final source = Source(file, repo);
        final target = Destination(
          UploadedChatFile(
            'owned',
            'test.bin',
            3,
            mode == 'mismatch' ? 'b' * 64 : 'a' * 64,
            'f',
            'r',
          ),
          repo,
        );
        if (mode == 'session') target.wait = Completer<void>();
        final forward = ChatFileForwarder(
          repository: repo,
          reference: ref,
          openDownloader: () async => source,
          openUploader: () async => target,
        );
        final prepared = forward.prepare();
        if (mode == 'session') {
          final check = expectLater(prepared, throwsStateError);
          while (target.uploads == 0) {
            await Future<void>.delayed(Duration.zero);
          }
          SecureSessionStore.changes.add(null);
          await Future<void>.delayed(Duration.zero);
          target.wait!.complete();
          await check;
        } else if (mode == 'mismatch') {
          await expectLater(prepared, throwsStateError);
        } else {
          expect((await prepared).assetId, 'owned');
          expect((await forward.prepare()).assetId, 'owned');
          expect(source.downloads, 1);
          expect(target.uploads, 1);
          expect(source.cleaned, false);
          expect(await file.exists(), true);
          expect(target.retained, 0);
          if (mode == 'retention-cancel') {
            target.retainWait = Completer<void>();
            final saving = forward.acknowledgeQueued();
            final rejected = expectLater(saving, throwsStateError);
            while (target.retained == 0) {
              await Future<void>.delayed(Duration.zero);
            }
            forward.dispose();
            expect(await file.exists(), true);
            target.retainWait!.complete();
            await rejected;
            expect(target.acknowledged, 0);
          } else if (mode == 'cancel') {
            forward.dispose();
            while (await file.exists()) {
              await Future<void>.delayed(Duration.zero);
            }
            expect(target.retained, 0);
            expect(target.acknowledged, 0);
          } else {
            await forward.acknowledgeQueued();
            expect(target.retained, 1);
            expect(target.acknowledged, 1);
          }
        }
        expect(source.cleaned, true);
        expect(await file.exists(), false);
        forward.dispose();
      },
    );
  }
}
