import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/material.dart';

/// App Store-style footer colors come from the footer, independently of the
/// poster headline. Warm artwork retains white labels; pale cool artwork gets
/// dark metadata and a slate-colored action. There is no live blur or border.
class TogetherFooterPalette {
  TogetherFooterPalette(Color background, {bool translucent = false}) {
    final opaque = background.withValues(alpha: 1);
    final tone = HSLColor.fromColor(opaque);
    final luminance = opaque.computeLuminance();
    // Pale pink and pale blue both need the dark action. Saturated warm
    // artwork (the orange reference) keeps a lighter action with white text.
    final light =
        luminance >= .62 ||
        (luminance >= .24 && HSVColor.fromColor(opaque).saturation <= .5);
    primary = light ? const Color(0xFF080A0C) : Colors.white;
    secondary = primary.withValues(alpha: .6);
    final Color computedAction;
    if (light) {
      computedAction = HSVColor.fromColor(opaque).saturation >= .2
          ? tone.withLightness(.32).toColor()
          : tone
                .withSaturation(tone.saturation * .3)
                .withLightness(.47)
                .toColor();
    } else {
      computedAction = Color.alphaBlend(
        Colors.white.withValues(alpha: .28),
        opaque,
      );
    }
    action = !translucent
        ? computedAction
        : light
        ? computedAction.withValues(alpha: .85)
        : Colors.white.withValues(alpha: .28);
    actionText = Colors.white;
  }
  late final Color primary, secondary, action, actionText;
}

class TogetherActivityAction extends StatelessWidget {
  const TogetherActivityAction({
    super.key,
    required this.palette,
    required this.label,
    required this.onPressed,
  });
  final TogetherFooterPalette palette;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final system = Theme.of(context).platform == TargetPlatform.iOS
        ? CupertinoTheme.of(context).textTheme.textStyle
        : const TextStyle();
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: palette.actionText,
        disabledForegroundColor: palette.actionText,
        minimumSize: const Size(74, 44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
        textStyle: system.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.2,
          letterSpacing: 0,
        ),
      ),
      child: DecoratedBox(
        key: const ValueKey('together-action-pill'),
        decoration: BoxDecoration(
          color: palette.action,
          borderRadius: BorderRadius.circular(100),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 74, minHeight: 32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(label, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
