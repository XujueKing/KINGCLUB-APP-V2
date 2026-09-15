import 'package:flutter/material.dart';

/// One text policy for pages, inputs and overlays; never changes device settings.
class KingTextScale extends StatelessWidget {
  const KingTextScale({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Flutter size is already in logical pixels; multiplying by physical
    // resolution/density again would magnify the user's display zoom twice.
    final compact = (media.size.shortestSide / 360).clamp(0.9, 1.0);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: 0.85 * compact,
          maxScaleFactor: 1.1 * compact,
        ),
      ),
      child: child,
    );
  }
}
