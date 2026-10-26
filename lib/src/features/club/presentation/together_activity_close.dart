import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'together_artwork_contrast.dart';

class TogetherCloseInk {
  TogetherCloseInk(Color background) {
    final light = background.computeLuminance() > .65;
    surface = Color.lerp(
      background,
      light ? Colors.white : Colors.black,
      .5,
    )!.withValues(alpha: .72);
    foreground = light
        ? Color.lerp(background, Colors.black, .9)!
        : Colors.white.withValues(alpha: .95);
    border = Colors.white.withValues(alpha: light ? .4 : .25);
  }
  late final Color surface, foreground, border;
}

/// A single clipped glass control. Poster sampling shares the existing cache;
/// the bounded backdrop blur is disabled while the card itself is in flight.
class TogetherActivityClose extends StatefulWidget {
  const TogetherActivityClose({
    super.key,
    required this.source,
    required this.scroll,
    required this.motion,
    required this.cardKey,
    required this.onPressed,
  });
  final String? source;
  final ScrollController scroll;
  final Animation<double> motion;
  final GlobalKey cardKey;
  final VoidCallback onPressed;
  @override
  State<TogetherActivityClose> createState() => _TogetherActivityCloseState();
}

class _TogetherActivityCloseState extends State<TogetherActivityClose> {
  static final _blur = ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7);
  late Future<TogetherArtworkSample?> _sample;
  @override
  void initState() {
    super.initState();
    _sample = TogetherArtworkContrast.sampleForSource(widget.source);
  }

  @override
  void didUpdateWidget(TogetherActivityClose old) {
    super.didUpdateWidget(old);
    if (old.source != widget.source) {
      _sample = TogetherArtworkContrast.sampleForSource(widget.source);
    }
  }

  Color _background(BuildContext context, TogetherArtworkSample? sample) {
    final width = MediaQuery.sizeOf(context).width;
    final box = widget.cardKey.currentContext?.findRenderObject() as RenderBox?;
    final height = box != null && box.hasSize
        ? box.size.height
        : width * 435 / 353;
    final top =
        MediaQuery.paddingOf(context).top +
        8 +
        (widget.scroll.hasClients ? widget.scroll.offset : 0);
    if (sample == null || top + 22 >= height) return const Color(0xFF1C1C1E);
    return sample.colorInRegion(
      width / height,
      Rect.fromLTWH(
        (width - 16 - 44) / width,
        top / height,
        44 / width,
        44 / height,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<TogetherArtworkSample?>(
    key: ValueKey(widget.source),
    future: _sample,
    initialData: TogetherArtworkContrast.cachedSample(widget.source),
    builder: (context, snapshot) => AnimatedBuilder(
      animation: Listenable.merge([widget.scroll, widget.motion]),
      builder: (context, _) {
        final ink = TogetherCloseInk(_background(context, snapshot.data));
        return RepaintBoundary(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 6,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                enabled:
                    widget.motion.value >= 1 &&
                    widget.motion.status != AnimationStatus.reverse,
                filter: _blur,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ink.border, width: .5),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ink.surface,
                        Color.alphaBlend(const Color(0x0FFFFFFF), ink.surface),
                      ],
                    ),
                  ),
                  child: IconButton(
                    key: const ValueKey('together-close-detail'),
                    tooltip: '关闭活动详情',
                    onPressed: widget.onPressed,
                    style: IconButton.styleFrom(
                      foregroundColor: ink.foreground,
                      fixedSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.close, size: 26),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
