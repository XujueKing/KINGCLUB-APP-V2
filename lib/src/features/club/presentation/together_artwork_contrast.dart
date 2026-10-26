import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/media/media_cache.dart';

/// Samples the displayed text region, rather than the unrelated top of a poster.
class TogetherArtworkSample {
  const TogetherArtworkSample(this.width, this.height, this.rgba, {this.file});
  final int width, height;
  final Uint8List rgba;
  final File? file;

  Color footerTint(double aspectRatio, {required bool blackText}) {
    final factor = math.max(aspectRatio / width, 1 / height);
    final left = (width * factor - aspectRatio) / 2;
    final top = (height * factor - 1) / 2;
    var red = 0.0, green = 0.0, blue = 0.0, count = 0;
    for (var y = 0; y < height; y++) {
      final dy = (y + .5) * factor - top;
      if (dy < .82 || dy > 1) continue;
      for (var x = 0; x < width; x++) {
        final dx = ((x + .5) * factor - left) / aspectRatio;
        if (dx < 0 || dx > 1) continue;
        final i = (y * width + x) * 4, alpha = rgba[i + 3] / 255;
        red += rgba[i] * alpha + 57 * (1 - alpha);
        green += rgba[i + 1] * alpha + 50 * (1 - alpha);
        blue += rgba[i + 2] * alpha + 41 * (1 - alpha);
        count++;
      }
    }
    var color = count == 0
        ? const Color(0xFF393229)
        : Color.fromARGB(
            255,
            (red / count).round(),
            (green / count).round(),
            (blue / count).round(),
          );
    if (blackText && color.computeLuminance() < .20) {
      color = Color.lerp(color, Colors.white, .55)!;
    }
    if (!blackText && color.computeLuminance() > .35) {
      color = Color.lerp(color, Colors.black, .5)!;
    }
    return color.withValues(alpha: .88);
  }

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
  const TogetherArtworkInk({
    this.black = false,
    this.ready = true,
    this.footerColor,
    this.posterFile,
  });
  final bool black, ready;
  final Color? footerColor;
  final File? posterFile;
  Color get flatFooter =>
      footerColor ??
      (black ? const Color(0xDDC0B9AC) : const Color(0xDD302B30));
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
  static final _resolved = <String, TogetherArtworkSample>{};
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
      final oldest = _samples.keys.first;
      _samples.remove(oldest);
      _resolved.remove(oldest);
    }
    late Future<TogetherArtworkSample?> pending;
    pending = Future<TogetherArtworkSample?>(() async {
      try {
        final Uint8List bytes;
        File? file;
        if (source.startsWith('assets/')) {
          final data = await rootBundle.load(source);
          bytes = data.buffer.asUint8List(
            data.offsetInBytes,
            data.lengthInBytes,
          );
        } else {
          file = await MediaCache.shared.get(source, scope: 'public');
          bytes = await file.readAsBytes();
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
                  format: ui.ImageByteFormat.rawStraightRgba,
                );
                if (data == null) return null;
                final sample = TogetherArtworkSample(
                  frame.image.width,
                  frame.image.height,
                  data.buffer.asUint8List(
                    data.offsetInBytes,
                    data.lengthInBytes,
                  ),
                  file: file,
                );
                if (identical(_samples[source], pending)) {
                  _resolved[source] = sample;
                }
                return sample;
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
    initialData: _resolved[widget.source],
    builder: (context, snapshot) => widget.builder(
      context,
      TogetherArtworkInk(
        posterFile: snapshot.data?.file,
        ready:
            widget.source == null ||
            snapshot.hasData ||
            snapshot.connectionState == ConnectionState.done,
        black: snapshot.data?.prefersBlack(widget.aspectRatio) ?? false,
        footerColor: snapshot.data?.footerTint(
          widget.aspectRatio,
          blackText: snapshot.data?.prefersBlack(widget.aspectRatio) ?? false,
        ),
      ),
    ),
  );
}
