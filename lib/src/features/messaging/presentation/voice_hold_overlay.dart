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
                  ) => AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: target == kind
                          ? (kind == VoiceHoldTarget.cancel
                                ? const Color(0xFFB76450)
                                : const Color(0xFFE4B780))
                          : const Color(0xFF302A24),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          size: 25,
                          color: target == kind
                              ? const Color(0xFF211810)
                              : const Color(0xFFC9B69E),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 14,
                            color: target == kind
                                ? const Color(0xFF211810)
                                : const Color(0xFFC9B69E),
                          ),
                        ),
                      ],
                    ),
                  );
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 220,
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: math.min(240, bounds.maxWidth * .66),
                              height: 88,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: cancel
                                      ? [
                                          const Color(0xFFE4A28E),
                                          const Color(0xFFB76450),
                                        ]
                                      : [
                                          const Color(0xFFF2D2A6),
                                          const Color(0xFFE4B780),
                                          const Color(0xFFD19A60),
                                        ],
                                ),
                                border: Border.all(
                                  color: const Color(0x55FFFFFF),
                                  width: .7,
                                ),
                              ),
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
                                          color: const Color(0xFF624326),
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
                                        color: Color(0xFF624326),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -5),
                              child: Transform.rotate(
                                angle: math.pi / 4,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: cancel
                                        ? const Color(0xFFB76450)
                                        : const Color(0xFFD19A60),
                                    borderRadius: BorderRadius.circular(3),
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
                        left: 42,
                        right: 42,
                        bottom: 102,
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
