import 'package:flutter/material.dart';

/// Use inside a centered registration surface: no vertical padding or counter
/// space may shift the single-line editable content away from the center.
InputDecoration registrationTextDecoration({
  String? hint,
  double horizontalPadding = 20,
}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: Color(0x99422E19), fontSize: 16),
  counterText: '',
  filled: false,
  isDense: true,
  isCollapsed: true,
  contentPadding: EdgeInsets.symmetric(horizontal: horizontalPadding),
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
);

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
