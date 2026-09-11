import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/storage_repository.dart';

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
}

class _LiquidClipper extends CustomClipper<Path> {
  _LiquidClipper(this.level, this.phase);
  final double level, phase;
  @override
  Path getClip(Size size) {
    final p = Path();
    final y = size.height * (1 - level.clamp(0, 1));
    final amplitude = level <= 0 || level >= 1 ? 0.0 : 3.0;
    p.moveTo(0, y);
    for (var x = 0.0; x <= size.width; x += 2) {
      p.lineTo(
        x,
        y +
            math.sin(x / size.width * math.pi * 2 + phase * math.pi * 2) *
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
