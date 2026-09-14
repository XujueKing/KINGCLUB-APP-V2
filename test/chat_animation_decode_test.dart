import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'server animation preview decodes distinct frames and timing in Flutter',
    () async {
      final bytes = await File('test/fixtures/chat-animation-preview.webp')
          .readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      addTearDown(codec.dispose);
      expect(codec.frameCount, 2);
      final first = await codec.getNextFrame();
      final second = await codec.getNextFrame();
      addTearDown(first.image.dispose);
      addTearDown(second.image.dispose);
      expect(first.duration, const Duration(milliseconds: 100));
      expect(second.duration, const Duration(milliseconds: 200));
      expect(first.image.width, 2);
      expect(first.image.height, 1);
      final red = (await first.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final blue = (await second.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(red.getUint8(0), greaterThan(200));
      expect(red.getUint8(2), lessThan(50));
      expect(blue.getUint8(0), lessThan(50));
      expect(blue.getUint8(2), greaterThan(200));
    },
  );
}
