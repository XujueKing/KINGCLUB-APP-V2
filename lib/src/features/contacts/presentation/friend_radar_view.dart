import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';

/// Positions are decorative, not a bearing or a precise location disclosure.
class FriendRadarView extends StatefulWidget {
  const FriendRadarView({
    super.key,
    required this.selfAvatar,
    required this.people,
    required this.active,
    required this.busy,
    required this.onToggle,
    required this.onBack,
    this.error,
  });
  final Widget selfAvatar;
  final List<({String account, Widget avatar, VoidCallback onTap})> people;
  final bool active, busy;
  final VoidCallback? onToggle;
  final VoidCallback onBack;
  final String? error;
  @override
  State<FriendRadarView> createState() => _FriendRadarViewState();
}

class _FriendRadarViewState extends State<FriendRadarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  @override
  void initState() {
    super.initState();
    if (widget.active) _sweep.repeat();
  }

  @override
  void didUpdateWidget(FriendRadarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_sweep.isAnimating) _sweep.repeat();
    if (!widget.active) _sweep.stop();
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _StarsPainter())),
        SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: KingBackButton.leftOffset(context),
                      top: KingBackButton.safeAreaOffset.dy,
                    ),
                    child: KingBackButton(onPressed: widget.onBack),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final diameter =
                        math.min(constraints.maxWidth, constraints.maxHeight) -
                        16;
                    return Center(
                      child: SizedBox.square(
                        dimension: diameter,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  painter: _RadarPainter(_sweep, widget.active),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFBBA887),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x40C9B69E),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: widget.selfAvatar,
                            ),
                            for (var i = 0; i < widget.people.length; i++)
                              Builder(
                                builder: (context) {
                                  final person = widget.people[i];
                                  final angle = i * 2.3999632297 - math.pi / 2;
                                  final radius =
                                      diameter * (.25 + (i % 3) * .075);
                                  return Positioned(
                                    key: ValueKey(person.account),
                                    left:
                                        diameter / 2 +
                                        math.cos(angle) * radius -
                                        24,
                                    top:
                                        diameter / 2 +
                                        math.sin(angle) * radius -
                                        24,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0, end: 1),
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      builder: (context, value, child) =>
                                          Opacity(
                                            opacity: value,
                                            child: Transform.scale(
                                              scale: .8 + .2 * value,
                                              child: child,
                                            ),
                                          ),
                                      child: Semantics(
                                        label: '查看附近朋友资料',
                                        button: true,
                                        child: GestureDetector(
                                          onTap: person.onTap,
                                          child: SizedBox.square(
                                            dimension: 48,
                                            child: person.avatar,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  children: [
                    Text(
                      widget.error ??
                          (widget.active
                              ? (widget.people.isEmpty
                                    ? '正在寻找附近的朋友…'
                                    : '发现 ${widget.people.length} 位朋友，点击头像认识一下')
                              : '与身边的朋友一起开启雷达'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.error == null
                            ? const Color(0xFFC9B69E)
                            : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '仅向附近同时开启雷达的人展示，头像位置不代表实际方位',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: widget.onToggle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC9B69E),
                        side: const BorderSide(color: Color(0x55C9B69E)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                      ),
                      child: Text(widget.active ? '停止雷达' : '开启雷达'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(930);
    for (var i = 0; i < 150; i++) {
      final p = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      canvas.drawCircle(
        p,
        .35 + random.nextDouble() * .7,
        Paint()
          ..color = Colors.white.withValues(
            alpha: .08 + random.nextDouble() * .3,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => false;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.progress, this.active) : super(repaint: progress);
  final Animation<double> progress;
  final bool active;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide * .46;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = const Color(0x35C9B69E);
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * i / 4, line);
    }
    if (!active) return;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(progress.value * math.pi * 2);
    final rect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final glow = Paint()
      ..shader = const SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 2,
        colors: [Color(0x00C9B69E), Color(0x38C9B69E)],
        tileMode: TileMode.clamp,
      ).createShader(rect);
    canvas.drawArc(rect, 0, math.pi / 2, true, glow);
    canvas.drawLine(
      Offset.zero,
      Offset(0, radius),
      Paint()
        ..color = const Color(0x99C9B69E)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.active != active;
}
