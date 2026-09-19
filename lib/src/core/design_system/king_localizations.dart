import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Simplified Chinese is the fallback; supported device languages remain respected.
const kingSupportedLocales = [
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
  Locale('en'),
  Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'TW'),
  Locale('th'),
];
const kingLocalizationDelegates = GlobalMaterialLocalizations.delegates;
