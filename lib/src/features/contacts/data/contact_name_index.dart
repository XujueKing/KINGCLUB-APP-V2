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

bool contactNameMatches({
  required String nickname,
  String? remark,
  required String account,
  required String query,
}) {
  final needle = query.trim().toUpperCase();
  if (needle.isEmpty || account.toUpperCase().contains(needle)) return true;
  for (final name in [nickname, ?remark]) {
    if (name.toUpperCase().contains(needle)) return true;
    if (!RegExp(r'^[A-Z\s]+$').hasMatch(needle)) continue;
    final letters = needle.replaceAll(RegExp(r'\s+'), '');
    if (contactPhoneticKey(name).contains(letters)) return true;
    try {
      if (PinyinHelper.getShortPinyin(name).toUpperCase().contains(letters)) {
        return true;
      }
    } catch (_) {
      // Unknown characters still support literal matching above.
    }
  }
  return false;
}
