import 'package:flutter/material.dart';

import 'king_theme.dart';

class KingBackButton extends StatelessWidget {
  const KingBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = '返回',
  });

  final VoidCallback? onPressed;
  final String tooltip;

  static const safeAreaOffset = Offset(18.5, 4);

  static double contentWidth(BuildContext context) =>
      (MediaQuery.sizeOf(context).width * .8).clamp(0.0, 480.0).toDouble();

  // Center the 8 dp glyph in its 48 dp touch target on the content edge.
  static double leftOffset(BuildContext context) =>
      (MediaQuery.sizeOf(context).width - contentWidth(context)) / 2 - 20;
  static const glyphSize = Size(8, 16);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Image.asset(
        'assets/legacy/friendship/back.png',
        width: glyphSize.width,
        height: glyphSize.height,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}

class KingRegistrationStepTitle extends StatelessWidget {
  const KingRegistrationStepTitle({super.key, required this.step});

  final int step;

  @override
  Widget build(BuildContext context) => Text(
    '当前步骤 $step/5',
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Color(0xB3C9B69E),
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.2,
    ),
  );
}

class KingBrandMark extends StatelessWidget {
  const KingBrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'KingClub',
      header: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 72,
            height: compact ? 48 : 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: KingColors.brand, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(
              'K',
              style: TextStyle(
                color: KingColors.brandStrong,
                fontSize: compact ? 24 : 34,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'KINGCLUB',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: KingColors.brandStrong, letterSpacing: 4),
          ),
        ],
      ),
    );
  }
}

class KingPageBody extends StatelessWidget {
  const KingPageBody({
    super.key,
    required this.child,
    this.padding,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: child,
          ),
        ),
      ),
    );
  }
}

class KingStatusCard extends StatelessWidget {
  const KingStatusCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = KingColors.brand,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KingColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KingColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
