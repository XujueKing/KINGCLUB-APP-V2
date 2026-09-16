import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/media/cached_media_image.dart';
import 'package:kingclub/src/core/media/media_cache.dart';

class PendingImages extends MediaCache {
  final requests = <Completer<File>>[];
  @override
  Future<File> get(
    String url, {
    required String scope,
    String? contentKey,
    MediaKind kind = MediaKind.image,
    Map<String, String>? headers,
  }) {
    final request = Completer<File>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  testWidgets(
    'changing image removes old pixels while replacement is pending',
    (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('image-transition-'),
      ))!;
      final file = File('${dir.path}/pixel.png');
      await tester.runAsync(
        () => file.writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aZ1sAAAAASUVORK5CYII=',
          ),
        ),
      );
      final cache = PendingImages();
      Widget view(String id, {String token = 'a'}) => MaterialApp(
        home: CachedMediaImage(
          'https://example.test/$id?token=$token',
          contentKey: id,
          keepSameImageOnRefresh: true,
          cache: cache,
          placeholder: const Text('pending'),
          errorBuilder: (_, _, _) => const SizedBox(),
        ),
      );
      await tester.pumpWidget(view('first'));
      cache.requests.single.complete(file);
      await tester.pump();
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpWidget(view('first', token: 'b'));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('pending'), findsNothing);
      cache.requests.last.complete(file);
      await tester.pump();
      await tester.pumpWidget(view('second'));
      expect(cache.requests.length, 3);
      expect(find.byType(Image), findsNothing);
      expect(find.text('pending'), findsOneWidget);
      // A response arriving after this page is closed cannot restore its image.
      await tester.pumpWidget(const SizedBox());
      cache.requests.last.complete(file);
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.runAsync(() async => dir.delete(recursive: true));
    },
  );
}
