import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/storage_repository.dart';
import '../data/bottle_material_preview.dart';
import 'bottle_material_image.dart';

/// Original bottle silhouettes; only the liquid surface is procedurally animated.
class StorageLiquidBottle extends StatefulWidget {
  const StorageLiquidBottle({
    super.key,
    required this.item,
    required this.active,
  });
  final StorageItem item;
  final bool active;
  @override
  State<StorageLiquidBottle> createState() => _StorageLiquidBottleState();
}

class _StorageLiquidBottleState extends State<StorageLiquidBottle>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(StorageLiquidBottle old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context)) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = widget.item;
    if (preview is BottlePreviewItem) return _previewBottle(preview);
    if (preview is LegacyBottleComparisonItem) {
      return _legacyComparison(preview);
    }
    final key = ['vodka', 'chivas', 'hennessy'].contains(widget.item.assetKey)
        ? widget.item.assetKey
        : 'vodka';
    return Stack(
      alignment: Alignment.center,
      children: [
        SvgPicture.asset(
          'assets/legacy/storage/$key-A.svg',
          colorFilter: const ColorFilter.mode(
            Color(0xFFC9B69E),
            BlendMode.srcIn,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: SvgPicture.asset(
            'assets/legacy/storage/$key-B.svg',
            colorFilter: const ColorFilter.mode(
              Color(0xFF211C14),
              BlendMode.srcIn,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: AnimatedBuilder(
            animation: _wave,
            builder: (context, _) => ClipPath(
              key: const ValueKey('storage-liquid-surface'),
              clipper: _LiquidClipper(
                widget.item.remainingPercent / 100,
                _wave.value,
              ),
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment(
                    -1 + math.sin(_wave.value * math.pi * 2),
                    -1,
                  ),
                  end: Alignment(1 + math.sin(_wave.value * math.pi * 2), 1),
                  colors: const [
                    Color(0xFF443626),
                    Color(0xFF80674A),
                    Color(0xFF443626),
                  ],
                ).createShader(bounds),
                child: SvgPicture.asset(
                  'assets/legacy/storage/$key-B.svg',
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF59452E),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          child: Column(
            children: [
              Text(
                '${widget.item.remainingPercent.toStringAsFixed(0)}%',
                style: const TextStyle(color: Color(0xFFC9B69E), fontSize: 21),
              ),
              Text(
                widget.item.expiresAt.isEmpty
                    ? ''
                    : widget.item.expiresLabel.split(' ').first,
                style: const TextStyle(color: Color(0xFFC9B69E), fontSize: 11),
              ),
              if (widget.item.status == 'expired')
                const Text(
                  '已过期',
                  style: TextStyle(color: Color(0xFFC9B69E), fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottleLabels(StorageItem item, double u) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${item.remainingPercent.toStringAsFixed(0)}%',
        style: TextStyle(
          color: const Color(0xFFC9B69E),
          fontSize: 40 * u,
          height: 1.2,
          fontWeight: FontWeight.w400,
        ),
      ),
      Text(
        item.expiresLabel.split(' ').first,
        style: TextStyle(
          color: const Color(0xFFC9B69E),
          fontSize: 22 * u,
          height: 1.4,
          fontWeight: FontWeight.w400,
        ),
      ),
    ],
  );

  Widget _materialLiquid(String mask, double level, double u) =>
      AnimatedBuilder(
        animation: _wave,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            // Old .bottle_progress: radial(circle 240rpx at 50% 100%, #443626, #c9b69e).
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => RadialGradient(
                center: Alignment.bottomCenter,
                radius: 240 * u / bounds.shortestSide,
                colors: const [Color(0xFF443626), Color(0xFFC9B69E)],
              ).createShader(bounds),
              child: SvgPicture.asset(mask, fit: BoxFit.contain),
            ),
            // Old moving dark liquid surface, clipped to the same bottle silhouette.
            ClipPath(
              key: const ValueKey('storage-liquid-surface'),
              clipper: _LegacyMaterialSurface(level / 100, _wave.value),
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => RadialGradient(
                  center: Alignment.topCenter,
                  radius: 500 * u / bounds.shortestSide,
                  colors: const [Color(0xFF52412F), Color(0xDD000000)],
                ).createShader(bounds),
                child: SvgPicture.asset(mask, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      );

  Widget _previewBottle(BottlePreviewItem item) {
    final u = MediaQuery.sizeOf(context).width / 750;
    return LayoutBuilder(
      builder: (context, box) {
        final imageHeight = math.min(
          box.maxHeight,
          box.maxWidth / item.imageAspectRatio,
        );
        final imageWidth = imageHeight * item.imageAspectRatio;
        return Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            BottleMaterialBacking(
              item: item,
              reverse: true,
              bodyHeight: imageHeight,
              bodyWidth: imageWidth,
            ),
            Center(
              child: OverflowBox(
                maxHeight: imageHeight * 1.08,
                maxWidth: imageHeight * 1.08 * item.aspectRatio,
                child: SizedBox(
                  key: ValueKey('bottle-reverse-canvas-${item.ref}'),
                  height: imageHeight * 1.08,
                  width: imageHeight * 1.08 * item.aspectRatio,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _materialLiquid(item.mask, item.remainingPercent, u),
                      SvgPicture.asset(item.outline, fit: BoxFit.contain),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: (box.maxHeight - imageHeight) / 2 + imageHeight * .66,
              left: 0,
              right: 0,
              child: Center(
                child: SizedBox(
                  width: math.max(1, imageWidth - 32 * u),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _bottleLabels(item, u),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _legacyComparison(LegacyBottleComparisonItem item) {
    final u = MediaQuery.sizeOf(context).width / 750;
    // Exact dimensions from legacy index.wxss; A = gold bottle, B = liquid mask.
    final dims = switch (item.assetKey) {
      'xo' => [311.0, 289.0, 460.0, 272.0, 443.0, -11.5],
      'vodka' => [217.0, 146.0, 453.0, 130.0, 437.0, -18.0],
      'chivas' => [216.0, 173.0, 449.0, 157.0, 434.0, -11.5],
      _ => [217.0, 167.0, 453.0, 153.0, 439.0, -11.5],
    };
    final prefix = '${BottlePreviewItem.directory}/legacy_${item.assetKey}';
    return Center(
      child: SizedBox(
        width: dims[0] * u,
        height: 490 * u,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SvgPicture.asset(
              '${prefix}_BJ.svg',
              width: dims[0] * u,
              height: 490 * u,
              colorFilter: const ColorFilter.mode(
                Color(0x33000000),
                BlendMode.srcIn,
              ),
            ),
            Transform.translate(
              offset: Offset(0, dims[5] * u / 2),
              child: SvgPicture.asset(
                '${prefix}_A.svg',
                width: dims[1] * u,
                height: dims[2] * u,
                colorFilter: const ColorFilter.mode(
                  Color(0xFFC9B69E),
                  BlendMode.srcIn,
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, -11.5 * u / 2),
              child: SizedBox(
                width: dims[3] * u,
                height: dims[4] * u,
                child: _materialLiquid(
                  '${prefix}_B.svg',
                  item.remainingPercent,
                  u,
                ),
              ),
            ),
            Positioned(
              top: 490 * u * .66,
              left: 0,
              right: 0,
              child: _bottleLabels(item, u),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidClipper extends CustomClipper<Path> {
  _LiquidClipper(this.level, this.phase);
  final double level, phase;
  @override
  Path getClip(Size size) {
    final p = Path();
    // 100% is a full usable bottle, not liquid up to the stopper.
    final fill = level.clamp(0.0, 1.0) * .90;
    final y = size.height * (1 - fill);
    final amplitude = math.min(3.0, size.height * fill * .08);
    p.moveTo(0, y);
    for (var x = 0.0; x <= size.width; x += 2) {
      p.lineTo(
        x,
        y +
            (math.sin(x / size.width * math.pi * 2 + phase * math.pi * 2) +
                    .3 *
                        math.sin(
                          x / size.width * math.pi * 4 - phase * math.pi * 2,
                        )) *
                amplitude,
      );
    }
    p.lineTo(size.width, size.height);
    p.lineTo(0, size.height);
    p.close();
    return p;
  }

  @override
  bool shouldReclip(_LiquidClipper old) =>
      old.level != level || old.phase != phase;
}

/// Match the legacy dark liquid / gold empty-bottle visual, keeping a stopper
/// above a full bottle. Percentage is not a physical volume-height calibration.
class _LegacyMaterialSurface extends CustomClipper<Path> {
  const _LegacyMaterialSurface(this.level, this.phase);
  final double level, phase;
  @override
  Path getClip(Size size) {
    final value = level.clamp(0.0, 1.0);
    if (value == 0) return Path();
    final y = size.height * (1 - value * .94);
    final p = Path()..moveTo(0, y);
    for (double x = 0; x <= size.width; x += 2) {
      p.lineTo(
        x,
        y +
            math.sin(x / size.width * math.pi * 4 + phase * math.pi * 2) *
                2 *
                value,
      );
    }
    return p
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_LegacyMaterialSurface old) =>
      old.level != level || old.phase != phase;
}
