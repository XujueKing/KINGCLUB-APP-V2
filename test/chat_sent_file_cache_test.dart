import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_sent_file_cache.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_uploader.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_cleanup.dart';

void main() {
  late Directory root;
  late ChatDownloadCache blocks;
  late ChatSentFileCache cache;
  var allowed = true;
  const asset = '00000000-0000-4000-8000-000000000001';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('chat-sent-cache-test-');
    allowed = true;
    blocks = ChatDownloadCache(
      root: Directory('${root.path}/encrypted'),
      key: await AesGcm.with256bits().newSecretKey(),
    );
    cache = ChatSentFileCache(
      cache: blocks,
      checkSession: () async {
        if (!allowed) throw StateError('Account changed');
      },
      temporaryDirectory: () async => root,
    );
  });
  tearDown(() => root.delete(recursive: true));
  Future<({File file, String hash})> source(List<int> data) async => (
    file: await File('${root.path}/original.bin').writeAsBytes(data),
    hash: (await Sha256().hash(data)).bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(),
  );
  Future<void> noPlaintext() async {
    expect(
      await root
          .list()
          .where((e) => e.path.contains('kingclub-peer-source-'))
          .toList(),
      isEmpty,
    );
  }

  test(
    'cleanup preserves shared sent file then releases final reference',
    () async {
      final input = await source([1, 2, 3]);
      await cache.retain(
        input.file,
        assetId: asset,
        size: 3,
        sha256: input.hash,
      );
      final downloads = ChatDownloadCache(
        root: Directory('${root.path}/downloads'),
        key: blocks.key,
      );
      final cleanup = ChatMediaCleanup(
        downloadCache: (_) async => downloads,
        sentFileCache: (_) async => blocks,
      );
      final message = <String, dynamic>{
        'messageType': 'file',
        'messageId': 'message',
        'sender': 'me',
        'fileAssetId': asset,
        'fileSize': 3,
        'fileSha256': input.hash,
        'fileName': 'source.bin',
      };
      await cleanup.remove(
        account: 'me',
        group: false,
        message: message,
        retainedFileAssets: {asset},
      );
      expect(
        await cache.use<bool>(
          assetId: asset,
          size: 3,
          sha256: input.hash,
          send: (file) async => await file.exists(),
        ),
        true,
      );
      await cleanup.remove(account: 'me', group: false, message: message);
      expect(
        await cache.use<bool>(
          assetId: asset,
          size: 3,
          sha256: input.hash,
          send: (_) async => fail('Deleted source must not be supplied'),
        ),
        isNull,
      );
      expect(await input.file.readAsBytes(), [1, 2, 3]);
      await cache.retain(
        input.file,
        assetId: asset,
        size: 3,
        sha256: input.hash,
      );
      expect(
        await cache.use<bool>(
          assetId: asset,
          size: 3,
          sha256: input.hash,
          send: (file) async => await file.exists(),
        ),
        true,
      );
      await noPlaintext();
    },
  );

  test(
    'queued uploader retains source; cache failure does not resend',
    () async {
      final input = await source([1, 2, 3]);
      var opens = 0;
      final uploader = ChatFileUploader(
        repository: MessagingRepository(
          account: 'test-member',
          call: (_, _) async => fail('Retention must not send another message'),
        ),
        checkSession: () async {},
        openSentCache: (account) async {
          expect(account, 'test-member');
          if (++opens > 1) throw FileSystemException('Cache unavailable');
          return blocks;
        },
      );
      addTearDown(uploader.dispose);
      final uploaded = UploadedChatFile(
        asset,
        'source.bin',
        3,
        input.hash,
        'fingerprint',
        'request',
      );
      await uploader.retainQueuedSource(input.file, uploaded);
      await input.file.delete();
      expect(
        await cache.use<bool>(
          assetId: asset,
          size: 3,
          sha256: input.hash,
          send: (file) async => (await file.readAsBytes()).join() == '123',
        ),
        isTrue,
      );
      await uploader.retainQueuedSource(input.file, uploaded);
      expect(opens, 2);
      uploader.dispose();
      await uploader.retainQueuedSource(input.file, uploaded);
      expect(opens, 2);
    },
  );

  for (final size in [0, 1048583]) {
    test('retains encrypted $size byte source after draft deletion', () async {
      final data = Uint8List.fromList(List.generate(size, (i) => i % 251));
      final input = await source(data);
      expect(
        await cache.retain(
          input.file,
          assetId: asset,
          size: size,
          sha256: input.hash,
        ),
        isTrue,
      );
      await input.file.delete();
      File? temporary;
      expect(
        await cache.use<bool>(
          assetId: asset,
          size: size,
          sha256: input.hash,
          send: (file) async {
            temporary = file;
            expect(await file.readAsBytes(), data);
            return true;
          },
        ),
        isTrue,
      );
      expect(await temporary!.exists(), isFalse);
      await noPlaintext();
      final files = await blocks.root
          .list(recursive: true)
          .where((e) => e is File && e.path.endsWith('.block'))
          .cast<File>()
          .toList();
      expect(files.length, size == 0 ? 1 : 2);
      expect(await files.first.readAsBytes(), isNot(equals(data)));
    });
  }

  test(
    'corrupt blocks are rejected but completed files do not expire',
    () async {
      final input = await source([1, 2, 3]);
      await cache.retain(
        input.file,
        assetId: asset,
        size: 3,
        sha256: input.hash,
      );
      final block =
          (await blocks.root
                  .list(recursive: true)
                  .where((e) => e is File && e.path.endsWith('.block'))
                  .cast<File>()
                  .toList())
              .single;
      final encrypted = await block.readAsBytes();
      encrypted[12] ^= 1;
      await block.writeAsBytes(encrypted);
      Future<void> denied() async {
        expect(
          await cache.use<bool>(
            assetId: asset,
            size: 3,
            sha256: input.hash,
            send: (_) async => fail('Must not send invalid bytes'),
          ),
          isNull,
        );
        await noPlaintext();
      }

      await denied();
      await cache.retain(
        input.file,
        assetId: asset,
        size: 3,
        sha256: input.hash,
      );
      await block.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(
        await cache.use<bool>(
          assetId: asset,
          size: 3,
          sha256: input.hash,
          send: (file) async {
            expect(await file.readAsBytes(), [1, 2, 3]);
            return true;
          },
        ),
        isTrue,
      );
      await noPlaintext();
    },
  );

  test('source change and account change clean partial retention', () async {
    final input = await source([1, 2, 3]);
    await input.file.writeAsBytes([3, 2, 1]);
    await expectLater(
      cache.retain(input.file, assetId: asset, size: 3, sha256: input.hash),
      throwsStateError,
    );
    expect(await blocks.root.list().toList(), isEmpty);
    await input.file.writeAsBytes([1, 2, 3]);
    var checks = 0;
    final changing = ChatSentFileCache(
      cache: blocks,
      checkSession: () async {
        if (++checks >= 3) throw StateError('Account changed');
      },
    );
    await expectLater(
      changing.retain(input.file, assetId: asset, size: 3, sha256: input.hash),
      throwsStateError,
    );
    expect(await blocks.root.list().toList(), isEmpty);
    expect(await input.file.readAsBytes(), [1, 2, 3]);
  });

  test(
    'sender error or late account change removes temporary plaintext',
    () async {
      final input = await source([1, 2, 3]);
      await cache.retain(
        input.file,
        assetId: asset,
        size: 3,
        sha256: input.hash,
      );
      await expectLater(
        cache.use<void>(
          assetId: asset,
          size: 3,
          sha256: input.hash,
          send: (_) async => throw StateError('Disconnected'),
        ),
        throwsStateError,
      );
      await noPlaintext();
      await expectLater(
        cache.use<void>(
          assetId: asset,
          size: 3,
          sha256: input.hash,
          send: (_) async {
            allowed = false;
          },
        ),
        throwsStateError,
      );
      await noPlaintext();
    },
  );

  test(
    'oversized file is skipped and completed entries remain retained',
    () async {
      final input = await source([1, 2, 3]);
      expect(
        await cache.retain(
          input.file,
          assetId: asset,
          size: ChatSentFileCache.maxBytes + 1,
          sha256: input.hash,
        ),
        isFalse,
      );
      expect(await blocks.root.exists(), isFalse);
      for (var i = 1; i <= 6; i++) {
        await cache.retain(
          input.file,
          assetId: '00000000-0000-4000-8000-00000000000$i',
          size: 3,
          sha256: input.hash,
        );
      }
      expect(await blocks.root.list().toList(), hasLength(6));
    },
  );
}
