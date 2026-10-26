import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shared by the close control and the activity action pills.
class TogetherGlassInk {
  TogetherGlassInk(Color background) {
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

class TogetherGlassSurface extends StatelessWidget {
  const TogetherGlassSurface({
    super.key,
    required this.ink,
    required this.radius,
    required this.child,
    this.blur = true,
  });
  final TogetherGlassInk ink;
  final double radius;
  final Widget child;
  final bool blur;
  static final _filter = ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7);

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x22000000),
          blurRadius: 6,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        enabled: blur,
        filter: _filter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
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
          child: child,
        ),
      ),
    ),
  );
}

/// The button retains its original hit target and disabled semantics. Only the
/// pill itself filters its backdrop; the card footer never gets a live blur.
class TogetherGlassAction extends StatelessWidget {
  const TogetherGlassAction({
    super.key,
    required this.ink,
    required this.label,
    required this.onPressed,
    required this.minimumSize,
    required this.padding,
    this.textStyle,
    this.blur = true,
  });
  final TogetherGlassInk ink;
  final String label;
  final VoidCallback? onPressed;
  final Size minimumSize;
  final EdgeInsets padding;
  final TextStyle? textStyle;
  final bool blur;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: ink.foreground,
      disabledForegroundColor: ink.foreground.withValues(alpha: .4),
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.padded,
      shape: const StadiumBorder(),
      textStyle: textStyle,
    ),
    child: TogetherGlassSurface(
      ink: ink,
      radius: 100,
      blur: blur,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: minimumSize.width,
          minHeight: minimumSize.height,
        ),
        child: Padding(
          padding: padding,
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    ),
  );
}
