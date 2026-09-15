import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_download_cache.dart';

void main() {
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
