import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';

void main() {
  test(
    'background crypto remains compatible with existing AES-GCM blocks',
    () async {
      final root = await Directory.systemTemp.createTemp('file-crypto-compat-');
      addTearDown(() => root.delete(recursive: true));
      final cipher = AesGcm.with256bits();
      final key = await cipher.newSecretKey();
      final cache = ChatDownloadCache(root: root, key: key);
      final bytes = Uint8List.fromList(
        List.generate(128 * 1024, (i) => i % 251),
      );
      await cache.write('message', 0, bytes);
      final block =
          (await root
                  .list(recursive: true)
                  .where((e) => e is File && e.path.endsWith('.block'))
                  .cast<File>()
                  .toList())
              .single;
      final aad = utf8.encode('message:0');
      expect(
        await cipher.decrypt(
          SecretBox.fromConcatenation(
            await block.readAsBytes(),
            nonceLength: 12,
            macLength: 16,
          ),
          secretKey: key,
          aad: aad,
        ),
        bytes,
      );
      final legacy = await cipher.encrypt(bytes, secretKey: key, aad: aad);
      await block.writeAsBytes(legacy.concatenation());
      expect(await cache.read('message', 0, bytes.length), bytes);
      final corrupt = await block.readAsBytes();
      corrupt[20] ^= 1;
      await block.writeAsBytes(corrupt);
      expect(await cache.read('message', 0, bytes.length), isNull);
    },
  );
  test(
    'completed files survive expiry, pruning and reopen until deleted',
    () async {
      final root = await Directory.systemTemp.createTemp('chat-file-retained-');
      addTearDown(() => root.delete(recursive: true));
      final key = await AesGcm.with256bits().newSecretKey();
      final cache = ChatDownloadCache(root: root, key: key);
      for (var i = 0; i < 7; i++) {
        await cache.write('saved-$i', 0, Uint8List.fromList([i]));
        await cache.retainCompleted('saved-$i');
      }
      await for (final file in root.list(recursive: true)) {
        if (file is File && file.path.endsWith('.block')) {
          await file.setLastModified(
            DateTime.now().subtract(const Duration(days: 30)),
          );
        }
      }
      final reopened = ChatDownloadCache(root: root, key: key);
      await reopened.prune('new-transfer');
      for (var i = 0; i < 7; i++) {
        expect(await reopened.read('saved-$i', 0, 1), [i]);
      }
      await reopened.removePermanently('saved-0');
      expect(await reopened.read('saved-0', 0, 1), isNull);
      await expectLater(reopened.retainCompleted('saved-0'), throwsStateError);
      expect(await reopened.read('saved-1', 0, 1), [1]);
    },
  );
  test(
    'permanent deletion survives reopening and blocks later writes',
    () async {
      final root = await Directory.systemTemp.createTemp('chat-file-delete-');
      addTearDown(() => root.delete(recursive: true));
      final key = await AesGcm.with256bits().newSecretKey();
      final cache = ChatDownloadCache(root: root, key: key);
      final bytes = Uint8List.fromList([1, 2, 3]);
      await cache.write('deleted-message', 0, bytes);
      await cache.write('kept-message', 0, bytes);
      await cache.removePermanently('deleted-message');
      final reopened = ChatDownloadCache(root: root, key: key);
      expect(await reopened.read('deleted-message', 0, 3), isNull);
      await expectLater(
        reopened.write('deleted-message', 1, bytes),
        throwsStateError,
      );
      await reopened.prune('kept-message');
      await expectLater(
        reopened.ensureNotDeleted('deleted-message'),
        throwsStateError,
      );
      expect(await reopened.read('kept-message', 0, 3), bytes);
      expect(
        await root
            .list(recursive: true)
            .where((e) => e.path.endsWith('.block'))
            .toList(),
        hasLength(1),
      );
    },
  );
  test(
    'cached blocks reject foreign keys, metadata, indices and expired data',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'chat-cache-security-',
      );
      addTearDown(() => root.delete(recursive: true));
      final key = await AesGcm.with256bits().newSecretKey();
      final cache = ChatDownloadCache(root: root, key: key);
      final data = Uint8List.fromList([1, 2, 3]);
      await cache.write('account-message-asset-hash', 0, data);
      expect(await cache.read('account-message-asset-hash', 0, 3), data);
      final wrongKey = ChatDownloadCache(
        root: root,
        key: await AesGcm.with256bits().newSecretKey(),
      );
      expect(await wrongKey.read('account-message-asset-hash', 0, 3), isNull);
      expect(
        await cache.read('other-account-message-asset-hash', 0, 3),
        isNull,
      );
      expect(await cache.read('account-message-asset-hash', 0, 4), isNull);
      final block =
          (await root
                  .list(recursive: true)
                  .where((e) => e is File)
                  .cast<File>()
                  .toList())
              .single;
      await block.copy('${block.parent.path}/1.block');
      expect(await cache.read('account-message-asset-hash', 1, 3), isNull);
      await block.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      expect(await cache.read('account-message-asset-hash', 0, 3), isNull);
    },
  );

  test('pruning preserves current transfer and bounds abandoned transfer directories', () async {
    final root = await Directory.systemTemp.createTemp('chat-cache-prune-');
    addTearDown(() => root.delete(recursive: true));
    final cache = ChatDownloadCache(
      root: root,
      key: await AesGcm.with256bits().newSecretKey(),
    );
    for (var i = 0; i < 6; i++) {
      await cache.write('transfer-$i', 0, Uint8List.fromList([i]));
    }
    await cache.prune('transfer-0');
    expect(await cache.read('transfer-0', 0, 1), [0]);
    expect(await root.list().toList(), hasLength(4));
    await cache.remove('transfer-0');
    expect(await cache.read('transfer-0', 0, 1), isNull);
  });
}
