import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/media/media_cache.dart';

/// Samples the displayed text region, rather than the unrelated top of a poster.
class TogetherArtworkSample {
  const TogetherArtworkSample(this.width, this.height, this.rgba);
  final int width, height;
  final Uint8List rgba;

  bool prefersBlack(double aspectRatio) {
    final target = Size(aspectRatio, 1);
    final factor = math.max(target.width / width, target.height / height);
    final left = (width * factor - target.width) / 2;
    final top = (height * factor - target.height) / 2;
    var luminance = 0.0;
    var count = 0;
    for (var y = 0; y < height; y++) {
      final dy = ((y + .5) * factor - top) / target.height;
      if (dy < .49 || dy > .83) continue;
      for (var x = 0; x < width; x++) {
        final dx = ((x + .5) * factor - left) / target.width;
        if (dx < .06 || dx > .94) continue;
        final i = (y * width + x) * 4;
        // Transparent pixels are displayed over this card's dark fallback.
        final alpha = rgba[i + 3] / 255;
        int channel(int value, int background) =>
            (value * alpha + background * (1 - alpha)).round();
        luminance += Color.fromARGB(
          255,
          channel(rgba[i], 57),
          channel(rgba[i + 1], 50),
          channel(rgba[i + 2], 41),
        ).computeLuminance();
        count++;
      }
    }
    if (count == 0) return false;
    final mean = luminance / count;
    return (mean + .05) / .05 >= 1.05 / (mean + .05);
  }
}

class TogetherArtworkInk {
  const TogetherArtworkInk({this.black = false, this.ready = true});
  final bool black, ready;
  Color get primary => black ? Colors.black : Colors.white;
  Color get secondary => primary.withValues(alpha: .60);
  Color get veil => black ? Colors.white : Colors.black;
  Color get glass => black
      ? Colors.black.withValues(alpha: .07)
      : Colors.white.withValues(alpha: .14);
}

/// Uses the existing public media cache and a bounded, tiny decoded sample.
/// There is no palette service, full-resolution decode, or second HTTP client.
class TogetherArtworkContrast extends StatefulWidget {
  const TogetherArtworkContrast({
    super.key,
    required this.source,
    required this.aspectRatio,
    required this.builder,
  });
  @visibleForTesting
  static Future<TogetherArtworkSample?> sampleForTesting(String source) =>
      _TogetherArtworkContrastState._load(source);

  final String? source;
  final double aspectRatio;
  final Widget Function(BuildContext, TogetherArtworkInk) builder;
  @override
  State<TogetherArtworkContrast> createState() =>
      _TogetherArtworkContrastState();
}

class _TogetherArtworkContrastState extends State<TogetherArtworkContrast> {
  static final _samples = <String, Future<TogetherArtworkSample?>>{};
  late Future<TogetherArtworkSample?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load(widget.source);
  }

  @override
  void didUpdateWidget(TogetherArtworkContrast oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _future = _load(widget.source);
  }

  static Future<TogetherArtworkSample?> _load(String? source) {
    if (source == null) return Future.value();
    final existing = _samples.remove(source);
    if (existing != null) {
      _samples[source] = existing;
      return existing;
    }
    while (_samples.length >= 32) {
      _samples.remove(_samples.keys.first);
    }
    late Future<TogetherArtworkSample?> pending;
    pending = Future<TogetherArtworkSample?>(() async {
      try {
        final Uint8List bytes;
        if (source.startsWith('assets/')) {
          final data = await rootBundle.load(source);
          bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } else {
          bytes = await (await MediaCache.shared.get(
            source,
            scope: 'public',
          )).readAsBytes();
        }
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        try {
          final descriptor = await ui.ImageDescriptor.encoded(buffer);
          try {
            final ratio = math.min(
              1.0,
              64 / math.max(descriptor.width, descriptor.height),
            );
            final codec = await descriptor.instantiateCodec(
              targetWidth: math.max(1, (descriptor.width * ratio).round()),
              targetHeight: math.max(1, (descriptor.height * ratio).round()),
            );
            try {
              final frame = await codec.getNextFrame();
              try {
                final data = await frame.image.toByteData(
                  format: ui.ImageByteFormat.rawRgba,
                );
                if (data == null) return null;
                return TogetherArtworkSample(
                  frame.image.width,
                  frame.image.height,
                  data.buffer.asUint8List(
                    data.offsetInBytes,
                    data.lengthInBytes,
                  ),
                );
              } finally {
                frame.image.dispose();
              }
            } finally {
              codec.dispose();
            }
          } finally {
            descriptor.dispose();
          }
        } finally {
          buffer.dispose();
        }
      } catch (_) {
        // A failed transfer/decode must not permanently pin this URL's decision.
        if (identical(_samples[source], pending)) _samples.remove(source);
        return null;
      }
    });
    _samples[source] = pending;
    return pending;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TogetherArtworkSample?>(
    key: ValueKey(widget.source),
    future: _future,
    builder: (context, snapshot) => widget.builder(
      context,
      TogetherArtworkInk(
        ready:
            widget.source == null ||
            snapshot.connectionState == ConnectionState.done,
        black: snapshot.data?.prefersBlack(widget.aspectRatio) ?? false,
      ),
    ),
  );
}
