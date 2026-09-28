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
      ..moveTo(edge - direction * 0.5, 15)
      ..lineTo(edge + direction * 6, 21)
      ..quadraticBezierTo(edge + direction * 6.7, 22, edge + direction * 6, 23)
      ..lineTo(edge - direction * 0.5, 29)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ChatBubbleTail oldDelegate) =>
      mine != oldDelegate.mine || color != oldDelegate.color;
}
