import 'package:flutter_svg/flutter_svg.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

enum VoiceHoldTarget { send, cancel, text }

class VoiceHoldOverlay extends StatefulWidget {
  const VoiceHoldOverlay({super.key, required this.target});
  final ValueNotifier<VoiceHoldTarget> target;
  @override
  State<VoiceHoldOverlay> createState() => _VoiceHoldOverlayState();
}

class _VoiceHoldOverlayState extends State<VoiceHoldOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();
  final started = DateTime.now();
  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 160),
        builder: (context, fade, child) => Opacity(opacity: fade, child: child),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xA6000000), Color(0xDD0D0B09), Color(0xFF17130F)],
            ),
          ),
          child: SafeArea(
            child: ValueListenableBuilder<VoiceHoldTarget>(
              valueListenable: widget.target,
              builder: (context, target, _) => LayoutBuilder(
                builder: (context, bounds) {
                  final cancel = target == VoiceHoldTarget.cancel;
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 220,
                        child: Column(
                          children: [
                            ClipPath(
                              clipper: const _VoiceBubbleClipper(),
                              child: Container(
                                width: math.min(220, bounds.maxWidth - 80),
                                height: 48,
                                padding: const EdgeInsets.only(bottom: 5),
                                color: cancel
                                    ? const Color(0xFFB76450)
                                    : const Color(0xFF29B463),
                                child: AnimatedBuilder(
                                  animation: motion,
                                  builder: (context, _) => Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ...List.generate(
                                        23,
                                        (i) => Container(
                                          width: 3,
                                          height:
                                              5 +
                                              17 *
                                                  (math
                                                      .sin(
                                                        i * .7 +
                                                            motion.value *
                                                                math.pi *
                                                                2,
                                                      )
                                                      .abs()),
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF20553D),
                                            borderRadius: BorderRadius.circular(
                                              2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${DateTime.now().difference(started).inSeconds}″',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF20553D),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              cancel
                                  ? '松开取消'
                                  : target == VoiceHoldTarget.text
                                  ? '松开转文字'
                                  : '松手发送',
                              style: const TextStyle(
                                color: Color(0xFFC9B69E),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: const ElasticOutCurve(.7),
                          builder: (context, t, _) => Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  key: const ValueKey('voice-hold-jelly-morph'),
                                  painter: _VoiceRingPainter(target, t),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 53,
                                child: Center(
                                  child: SvgPicture.asset(
                                    'assets/legacy/messaging/microphone.svg',
                                    width: 30,
                                    height: 30,
                                    colorFilter: const ColorFilter.mode(
                                      Color(0xFF624326),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// One continuous outline: rounded body and curved tail share the same fill.
class _VoiceBubbleClipper extends CustomClipper<Path> {
  const _VoiceBubbleClipper();
  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height - 5, c = size.width / 2;
    return Path()
      ..moveTo(7, 0)
      ..lineTo(w - 7, 0)
      ..quadraticBezierTo(w, 0, w, 7)
      ..lineTo(w, h - 7)
      ..quadraticBezierTo(w, h, w - 7, h)
      ..lineTo(c + 5, h)
      ..lineTo(c, h + 5)
      ..lineTo(c - 5, h)
      ..lineTo(7, h)
      ..quadraticBezierTo(0, h, 0, h - 7)
      ..lineTo(0, 7)
      ..quadraticBezierTo(0, 0, 7, 0)
      ..close();
  }

  @override
  bool shouldReclip(_VoiceBubbleClipper oldClipper) => false;
}

// Continuous concentric band, divided at its center with a fine radial line.
class _VoiceRingPainter extends CustomPainter {
  _VoiceRingPainter(this.target, this.progress);
  final VoiceHoldTarget target;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width * 1.15;
    final center = Offset(size.width / 2, size.height - 115 + radius);
    final thickness = size.width * (78 / 504);
    final ringRadius = radius + size.width * (58 / 504);
    final rect = Rect.fromCircle(center: center, radius: ringRadius);
    for (final left in [true, false]) {
      final kind = left ? VoiceHoldTarget.cancel : VoiceHoldTarget.text;
      final paint = Paint()
        ..color = target == kind
            ? (left ? const Color(0xFFB76450) : const Color(0xFF64CB99))
            : const Color(0xFFD3D3D3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt;
      final start = left ? -math.pi : -math.pi / 2;
      final sweep = math.pi / 2;
      canvas.drawArc(rect, start, sweep, false, paint);
      final textAngle = (left ? -1 : 1) * .215;
      final label = left ? '取消' : '滑到这里 转文字';
      final glyphs = label.characters
          .map(
            (character) => TextPainter(
              text: TextSpan(
                text: character,
                style: TextStyle(
                  color: target == kind
                      ? const Color(0xFF15271F)
                      : const Color(0xFF242424),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              textDirection: TextDirection.ltr,
            )..layout(),
          )
          .toList();
      final totalWidth = glyphs.fold<double>(
        0,
        (sum, glyph) => sum + glyph.width,
      );
      var distance = -totalWidth / 2;
      for (final glyph in glyphs) {
        final angle = textAngle + (distance + glyph.width / 2) / ringRadius;
        final anchor =
            center +
            Offset(math.sin(angle) * ringRadius, -math.cos(angle) * ringRadius);
        canvas.save();
        canvas.translate(anchor.dx, anchor.dy);
        canvas.rotate(angle);
        glyph.paint(canvas, Offset(-glyph.width / 2, -glyph.height / 2));
        canvas.restore();
        distance += glyph.width;
        glyph.dispose();
      }
    }
    canvas.drawLine(
      Offset(center.dx, center.dy - ringRadius - thickness / 2),
      Offset(center.dx, center.dy - ringRadius + thickness / 2),
      Paint()
        ..color = const Color(0x66808080)
        ..strokeWidth = .7,
    );
    final t = progress;
    final startWidth = size.width * .92;
    final width = startWidth + (radius * 2 - startWidth) * t;
    final height = 40 + (radius * 2 - 40) * t;
    final top =
        (size.height - 62) + ((center.dy - radius) - (size.height - 62)) * t;
    final body = Rect.fromLTWH((size.width - width) / 2, top, width, height);
    final shape = RRect.fromRectAndRadius(
      body,
      Radius.circular(20 + (radius - 20) * t),
    );
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFF2D2A6), Color(0xFFE4B780), Color(0xFFD19A60)],
      ).createShader(Rect.fromLTWH(0, top, size.width, 180));
    canvas.drawRRect(shape, paint);
    canvas.drawRRect(
      shape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x88FFE6C6),
    );
  }

  @override
  bool shouldRepaint(_VoiceRingPainter old) =>
      old.target != target || old.progress != progress;
}
