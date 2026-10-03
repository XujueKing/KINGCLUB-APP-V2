import 'package:flutter/material.dart';

/// Real text replacing the legacy English raster label. Keep the English copy
/// until the language editions are introduced; callers can then pass localized
/// copy without changing the ticket geometry or creating another image asset.
class PositioningCardLabel extends StatelessWidget {
  const PositioningCardLabel({
    super.key,
    this.text = 'POSITIONING CARD',
    this.width = 135,
    this.height = 18,
    this.color = const Color(0xFFFBAFDA),
  });

  final String text;
  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Bebas Neue covers Latin, not Chinese or Thai. Let the platform's script fonts
    // shape translated copy, with room for Thai marks above/below the baseline.
    final latin = RegExp(r'^[\x20-\x7E]*$').hasMatch(text);
    return SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontFamily: latin ? 'BebasNeue' : null,
            fontSize: latin ? 25 : 21,
            fontWeight: latin ? FontWeight.w400 : FontWeight.w600,
            height: latin ? .72 : 1.35,
            letterSpacing: 0,
            color: color,
          ),
        ),
      ),
    );
  }
}
