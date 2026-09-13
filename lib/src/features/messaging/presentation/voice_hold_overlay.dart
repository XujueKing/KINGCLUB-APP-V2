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
                  Widget action(
                    VoiceHoldTarget kind,
                    IconData icon,
                    String label,
                  ) {
                    final left = kind == VoiceHoldTarget.cancel;
                    final color = target == kind
                        ? (left ? '#B76450' : '#64CB99')
                        : '#292929';
                    return SizedBox(
                      width: bounds.maxWidth * (267 / 579),
                      height: bounds.maxWidth * (143 / 579),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: Transform.flip(
                              flipX: !left,
                              child: SvgPicture.string(
                                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 267 143"><path fill="$color" d="M0 41 C75 20 151 4 210 0 C242 -2 267 20 267 50 C267 78 249 96 220 100 C143 105 66 123 0 143 Z"/></svg>',
                                fit: BoxFit.fill,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(
                              left: left ? 8 : 0,
                              right: left ? 0 : 8,
                              top: 12,
                            ),
                            child: Transform.rotate(
                              angle: left ? -.16 : .16,
                              child: Text(
                                left ? '取消' : '滑到这里 转文字',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: target == kind
                                      ? const Color(0xFF15271F)
                                      : const Color(0xFFCCCCCC),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

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
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 115,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            action(VoiceHoldTarget.cancel, Icons.close, '取消'),
                            action(
                              VoiceHoldTarget.text,
                              Icons.text_fields,
                              '转文字',
                            ),
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 650),
                          curve: const ElasticOutCurve(.7),
                          builder: (context, t, _) {
                            final r = bounds.maxWidth / 750;
                            final width =
                                (bounds.maxWidth - 60 * r) +
                                (bounds.maxWidth * .4 + 60 * r) * t;
                            final height = 80 * r + (180 - 80 * r) * t;
                            final bottom = 22 * r + (-65 - 22 * r) * t;
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  key: const ValueKey('voice-hold-jelly-morph'),
                                  left: (bounds.maxWidth - width) / 2,
                                  bottom: bottom,
                                  width: width,
                                  height: height,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.elliptical(
                                          width / 2,
                                          24 + 90 * t,
                                        ),
                                        bottom: const Radius.circular(28),
                                      ),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFFF2D2A6),
                                          Color(0xFFE4B780),
                                          Color(0xFFD19A60),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: const Color(0x88FFE6C6),
                                        width: 1.2,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x44C99254),
                                          blurRadius: 12,
                                        ),
                                      ],
                                    ),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          top: 8 + 24 * t,
                                        ),
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
                                  ),
                                ),
                              ],
                            );
                          },
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
