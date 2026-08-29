import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/core/mock/mock_runtime.dart';
import 'package:kingclub/src/features/onboarding/presentation/drink_event_preferences_page.dart';
import 'package:kingclub/src/features/onboarding/presentation/style_music_preferences_page.dart';

Widget _screen(MockRuntime runtime, Widget child) => ProviderScope(
  overrides: [mockRuntimeProvider.overrideWithValue(runtime)],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: KingTheme.dark,
    home: RepaintBoundary(key: const ValueKey('capture'), child: child),
  ),
);

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  testWidgets('style and music catalog visual states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();

    await tester.pumpWidget(
      _screen(
        runtime,
        StyleMusicPreferencesPage(
          flowId: flowId,
          onBack: () {},
          onNext: () {},
          onInvalidFlow: () {},
        ),
      ),
    );
    await tester.tap(find.text('高级酒会小礼服'));
    await tester.tap(find.text('纯欲风'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/onboarding_style_music_top_393x852.png'),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -430),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/onboarding_style_music_bottom_393x852.png'),
    );
  });

  testWidgets('drink and event catalog visual states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtime = MockRuntime();
    final flowId = runtime.startOnboarding();

    await tester.pumpWidget(
      _screen(
        runtime,
        DrinkEventPreferencesPage(
          flowId: flowId,
          onBack: () {},
          onSubmitted: () {},
          onInvalidFlow: () {},
        ),
      ),
    );
    await tester.tap(find.text('无酒精'));
    await tester.tap(find.text('白兰地'));
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/onboarding_drink_event_top_393x852.png'),
    );

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('capture')),
      matchesGoldenFile('goldens/onboarding_drink_event_bottom_393x852.png'),
    );
  });
}
