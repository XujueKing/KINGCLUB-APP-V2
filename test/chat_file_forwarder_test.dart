import 'dart:async';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_forwarder.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_sent_file_cache.dart';

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
  Destination(this.asset, MessagingRepository repo, {this.cache})
    : super(
        repository: repo,
        checkSession: () async {},
        openSentCache: cache == null ? null : (_) async => cache,
      );
  final ChatDownloadCache? cache;
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
    if (cache != null) await super.retainQueuedSource(source, file);
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
  test('queued forward is readable from reopened encrypted source after plaintext cleanup', () async {
    final dir = await Directory.systemTemp.createTemp('forward-disk-');
    addTearDown(() => dir.delete(recursive: true));
    final key = await AesGcm.with256bits().newSecretKey();
    final root = Directory('${dir.path}/encrypted');
    final cache = ChatDownloadCache(root: root, key: key);
    final bytes = [1, 2, 3];
    final hash = (await Sha256().hash(bytes)).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    const assetId = '12345678-1234-1234-1234-123456789012';
    final file = await File('${dir.path}/source').writeAsBytes(bytes);
    final repo = MessagingRepository(
      account: 'me',
      call: (_, _) async => throw StateError('Unexpected network access'),
    );
    final source = Source(file, repo);
    final target = Destination(
      UploadedChatFile(assetId, 'test.bin', 3, hash, 'f', 'r'),
      repo,
      cache: cache,
    );
    final forward = ChatFileForwarder(
      repository: repo,
      reference: ChatFileReference(
        messageId: 'm',
        assetId: 'original',
        fileName: 'test.bin',
        size: 3,
        sha256: hash,
      ),
      openDownloader: () async => source,
      openUploader: () async => target,
    );
    addTearDown(forward.dispose);
    await forward.prepare();
    expect(await root.exists(), false);
    await forward.acknowledgeQueued();
    expect(await file.exists(), false);
    final reopened = ChatSentFileCache(
      cache: ChatDownloadCache(root: root, key: key),
      checkSession: () async {},
      temporaryDirectory: () async => dir,
    );
    File? decoded;
    final restored = await reopened.use<bool>(
      assetId: assetId,
      size: 3,
      sha256: hash,
      send: (local) async {
        decoded = local;
        expect(await local.readAsBytes(), bytes);
        return true;
      },
    );
    expect(restored, true);
    expect(await decoded!.exists(), false);
    await reopened.remove(assetId: assetId, size: 3, sha256: hash);
    expect(await root.list().toList(), isEmpty);
  });
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
