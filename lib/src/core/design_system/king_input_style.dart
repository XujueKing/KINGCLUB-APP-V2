import 'package:flutter/material.dart';

import 'king_control_sizes.dart';

const kingInputBackground = Color(0xff1c1c1e);
const kingInputBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(12)),
  borderSide: BorderSide.none,
);
const kingSearchTextStyle = TextStyle(
  color: Colors.white,
  fontSize: 16,
  fontWeight: FontWeight.w400,
  height: 1.25,
);

double kingSearchHeight(BuildContext context) {
  final textHeight = MediaQuery.textScalerOf(context).scale(16) * 1.25 + 28;
  return textHeight > kingControlHeight ? textHeight : kingControlHeight;
}

InputDecoration kingSearchDecoration({
  String? hintText,
  Widget? prefixIcon = const Icon(Icons.search, size: 22),
  Widget? suffixIcon,
  String? counterText,
}) => InputDecoration(
  hintText: hintText,
  hintStyle: kingSearchTextStyle.copyWith(color: Colors.white54),
  filled: true,
  fillColor: kingInputBackground,
  isDense: true,
  constraints: const BoxConstraints(minHeight: kingControlHeight),
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  prefixIcon: prefixIcon,
  prefixIconColor: Colors.white54,
  suffixIcon: suffixIcon,
  suffixIconColor: Colors.white54,
  counterText: counterText,
  border: kingInputBorder,
  enabledBorder: kingInputBorder,
  focusedBorder: kingInputBorder,
  disabledBorder: kingInputBorder,
  errorBorder: kingInputBorder,
  focusedErrorBorder: kingInputBorder,
);
