import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/media_cache.dart';

void main() {
  testWidgets(
    'message deletion removes decoded image and disk copy only for its key',
    (tester) async {
      late Directory root;
      late MediaCache store;
      late File removed, kept;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('decoded-image-delete-');
        store = MediaCache(
          directory: () async => root,
          onImageEvicted: (file) async {
            await FileImage(file).evict();
          },
        );
        final bytes = await File('assets/legacy/storage/wine_flip.png')
            .readAsBytes();
        removed = await store.importBytes(
          bytes,
          scope: 'member:a',
          contentKey: 'deleted-message',
          kind: MediaKind.image,
        );
        kept = await store.importBytes(
          bytes,
          scope: 'member:a',
          contentKey: 'kept-message',
          kind: MediaKind.image,
        );
      });
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox).first);
      await tester.runAsync(() async {
        await precacheImage(FileImage(removed), context);
        await precacheImage(FileImage(kept), context);
      });
      await tester.pump();
      final cache = PaintingBinding.instance.imageCache;
      expect(cache.containsKey(FileImage(removed)), true);
      expect(cache.containsKey(FileImage(kept)), true);
      await tester.runAsync(() async {
        await store.removePermanently(
          scope: 'member:a',
          contentKey: 'deleted-message',
          kind: MediaKind.image,
        );
        expect(await removed.exists(), false);
        expect(await kept.exists(), true);
      });
      expect(cache.containsKey(FileImage(removed)), false);
      expect(cache.containsKey(FileImage(kept)), true);
      await tester.pumpWidget(const SizedBox());
      await FileImage(kept).evict();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
