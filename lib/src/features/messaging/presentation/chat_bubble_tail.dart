import 'package:flutter/material.dart';

/// Painted outside the body so the text layout and avatar gap stay stable.
class ChatBubbleTail extends CustomPainter {
  const ChatBubbleTail({required this.mine, required this.color});
  final bool mine;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final edge = mine ? size.width : 0.0;
    final direction = mine ? 1.0 : -1.0;
    final path = Path()
      ..moveTo(edge - direction * 0.5, 17.5)
      ..lineTo(edge + direction * 4, 21.5)
      ..quadraticBezierTo(
        edge + direction * 4.4,
        22,
        edge + direction * 4,
        22.5,
      )
      ..lineTo(edge - direction * 0.5, 26.5)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ChatBubbleTail oldDelegate) =>
      mine != oldDelegate.mine || color != oldDelegate.color;
}
