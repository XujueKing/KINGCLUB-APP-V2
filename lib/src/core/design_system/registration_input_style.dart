import 'package:flutter/material.dart';

/// Shared legacy registration surface. Flutter scales a radial gradient by
/// the shortest side; the legacy 600rpx circle uses a 300dp radius.
BoxDecoration registrationInputDecoration({
  required double height,
  BorderRadius? borderRadius,
}) => BoxDecoration(
  borderRadius: borderRadius ?? BorderRadius.circular(height / 2),
  gradient: RadialGradient(
    center: Alignment.topLeft,
    radius: 300 / height,
    colors: const [Color(0xFFB8A289), Color(0xFF7E6951)],
  ),
);
