import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'king_localizations.dart';

const kingLanguageNames = ['简体中文', 'English', '繁體中文', 'ไทย'];

int kingLanguageIndex(Locale locale) => switch (locale.languageCode) {
  'en' => 1,
  'th' => 3,
  'zh'
      when locale.scriptCode == 'Hant' ||
          const ['TW', 'HK', 'MO'].contains(locale.countryCode) =>
    2,
  _ => 0,
};

String kingText(Locale locale, List<String> values) =>
    values[kingLanguageIndex(locale)];

/// Device preference, separate from login/session data. Null follows the device.
class KingLanguage extends ValueNotifier<Locale?> {
  KingLanguage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      super(null);

  static final shared = KingLanguage();
  static const storageKey = 'kingclub.preference.language';
  final FlutterSecureStorage _storage;

  Future<void> load() async {
    try {
      final saved = await _storage.read(key: storageKey);
      for (final locale in kingSupportedLocales) {
        if (locale.toLanguageTag() == saved) {
          value = locale;
          return;
        }
      }
    } catch (_) {
      // A locked device's preference must not prevent startup.
    }
  }

  Future<void> select(Locale locale) async {
    final supported = kingSupportedLocales[kingLanguageIndex(locale)];
    await _storage.write(key: storageKey, value: supported.toLanguageTag());
    value = supported;
  }
}
