import 'package:lpinyin/lpinyin.dart';

/// Sort by the visible name. Non-alphabetic names stay in the final # section.
String contactPhoneticKey(String name) {
  final value = name.trim();
  try {
    return PinyinHelper.getPinyin(
      value,
      separator: '',
      format: PinyinFormat.WITHOUT_TONE,
    ).toUpperCase();
  } catch (_) {
    return value.toUpperCase();
  }
}

String contactIndexSection(String key) =>
    key.isNotEmpty && RegExp(r'^[A-Z]').hasMatch(key) ? key[0] : '#';
