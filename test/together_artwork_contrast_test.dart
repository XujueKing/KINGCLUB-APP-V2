import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/presentation/together_artwork_contrast.dart';

TogetherArtworkSample sample(
  int width,
  int height,
  Color Function(int, int) pixel,
) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final color = pixel(x, y).toARGB32();
      final i = (y * width + x) * 4;
      bytes[i] = (color >> 16) & 255;
      bytes[i + 1] = (color >> 8) & 255;
      bytes[i + 2] = color & 255;
      bytes[i + 3] = (color >> 24) & 255;
    }
  }
  return TogetherArtworkSample(width, height, bytes);
}

void main() {
  testWidgets(
    'decoded asset decisions follow source changes and reuse samples',
    (tester) async {
      Future<Uint8List> png(Color color) async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(color, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(8, 8);
        try {
          final data = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          return data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } finally {
          image.dispose();
          picture.dispose();
        }
      }

      final light = (await tester.runAsync(() => png(Colors.white)))!;
      final dark = (await tester.runAsync(() => png(Colors.black)))!;
      final loads = <String, int>{};
      var failOnce = true;
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        (message) async {
          final name = utf8.decode(
            message!.buffer.asUint8List(
              message.offsetInBytes,
              message.lengthInBytes,
            ),
          );
          loads[name] = (loads[name] ?? 0) + 1;
          if (name.endsWith('retry-208.png') && failOnce) {
            failOnce = false;
            return null;
          }
          return ByteData.sublistView(
            name.endsWith('dark-208.png') ? dark : light,
          );
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/assets',
          null,
        ),
      );
      var ready = false;
      Widget host(String source) => Directionality(
        textDirection: TextDirection.ltr,
        child: TogetherArtworkContrast(
          source: source,
          aspectRatio: 353 / 435,
          builder: (_, ink) {
            ready = ink.ready;
            return ColoredBox(key: const ValueKey('ink'), color: ink.primary);
          },
        ),
      );
      Future<void> show(String source) async {
        ready = false;
        await tester.pumpWidget(host(source));
        for (var frame = 0; frame < 20 && !ready; frame++) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        await tester.pumpAndSettle();
        expect(ready, isTrue);
      }

      await tester.runAsync(
        () =>
            TogetherArtworkContrast.sampleForTesting('assets/qa/light-208.png'),
      );
      await tester.runAsync(
        () =>
            TogetherArtworkContrast.sampleForTesting('assets/qa/dark-208.png'),
      );
      await show('assets/qa/light-208.png');
      expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey('ink'))).color,
        Colors.black,
      );
      await show('assets/qa/dark-208.png');
      expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey('ink'))).color,
        Colors.white,
      );
      await show('assets/qa/light-208.png');
      expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey('ink'))).color,
        Colors.black,
      );
      expect(loads['assets/qa/light-208.png'], 1);
      await tester.runAsync(
        () =>
            TogetherArtworkContrast.sampleForTesting('assets/qa/retry-208.png'),
      );
      await tester.runAsync(
        () =>
            TogetherArtworkContrast.sampleForTesting('assets/qa/retry-208.png'),
      );
      await show('assets/qa/retry-208.png');
      expect(
        tester.widget<ColoredBox>(find.byKey(const ValueKey('ink'))).color,
        Colors.black,
      );
      expect(loads['assets/qa/retry-208.png'], 2);
      expect(tester.takeException(), isNull);
    },
  );
  test('bright artwork uses black; dark artwork uses white', () {
    expect(
      sample(32, 32, (_, _) => Colors.white).prefersBlack(353 / 435),
      isTrue,
    );
    expect(
      sample(32, 32, (_, _) => const Color(0xFFDFF3A7)).prefersBlack(353 / 435),
      isTrue,
    );
    expect(
      sample(32, 32, (_, _) => Colors.black).prefersBlack(353 / 435),
      isFalse,
    );
    expect(
      sample(32, 32, (_, _) => const Color(0xFF351130)).prefersBlack(353 / 435),
      isFalse,
    );
  });

  test('text region takes precedence over a bright top half', () {
    expect(
      sample(
        32,
        32,
        (_, y) => y < 16 ? Colors.white : Colors.black,
      ).prefersBlack(1),
      isFalse,
    );
  });

  test('cover crop excludes bright sides that are not displayed', () {
    expect(
      sample(
        64,
        16,
        (x, _) => x >= 24 && x < 40 ? Colors.black : Colors.white,
      ).prefersBlack(353 / 435),
      isFalse,
    );
  });

  test('transparent artwork uses the actual dark fallback', () {
    expect(
      sample(32, 32, (_, _) => Colors.transparent).prefersBlack(1),
      isFalse,
    );
  });

  test(
    'partial transparent light pixels composite over the dark surface once',
    () {
      expect(
        sample(32, 32, (_, _) => const Color(0x80FFFFFF)).prefersBlack(1),
        isTrue,
      );
    },
  );

  test('small text uses the same black or white ink at sixty percent', () {
    const light = TogetherArtworkInk(black: true);
    const dark = TogetherArtworkInk();
    expect(light.primary, Colors.black);
    expect(dark.primary, Colors.white);
    expect(light.secondary.a, closeTo(.6, .001));
    expect(dark.secondary.a, closeTo(.6, .001));
  });
}
