import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_language.dart';
import 'package:kingclub/src/core/design_system/king_localizations.dart';
import 'package:kingclub/src/features/profile_settings/presentation/language_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('all four choices persist and restore without session data', () async {
    for (final locale in kingSupportedLocales) {
      final preference = KingLanguage();
      await preference.select(locale);
      final restored = KingLanguage();
      await restored.load();
      expect(restored.value, locale);
      preference.dispose();
      restored.dispose();
    }
  });

  test(
    'absent and invalid preference leave device locale resolution intact',
    () async {
      final preference = KingLanguage();
      await preference.load();
      expect(preference.value, isNull);
      await const FlutterSecureStorage().write(
        key: KingLanguage.storageKey,
        value: 'invalid',
      );
      await preference.load();
      expect(preference.value, isNull);
      expect(kingLanguageIndex(const Locale('zh', 'HK')), 2);
      preference.dispose();
    },
  );

  testWidgets('select language updates locale without replacing navigation', (
    tester,
  ) async {
    final preference = KingLanguage();
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: preference,
        builder: (_, _) => MaterialApp(
          locale: preference.value,
          supportedLocales: kingSupportedLocales,
          localizationsDelegates: kingLocalizationDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LanguageSettingsPage(language: preference),
                  ),
                ),
                child: Text(
                  'open:${Localizations.localeOf(context).languageCode}',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (final locale in kingSupportedLocales) {
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      for (final name in kingLanguageNames) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.tap(
        find.byKey(ValueKey('language-${locale.toLanguageTag()}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LanguageSettingsPage), findsNothing);
      expect(find.text('open:${locale.languageCode}'), findsOneWidget);
      expect(preference.value, locale);
    }
    await tester.pumpWidget(const SizedBox());
    preference.dispose();
  });
}
