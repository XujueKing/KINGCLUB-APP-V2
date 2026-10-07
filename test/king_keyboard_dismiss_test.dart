import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_keyboard_dismiss.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('touch outside dismisses on $platform and preserves controls', (
      tester,
    ) async {
      final first = FocusNode(), second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: platform),
          builder: (_, child) => KingKeyboardDismiss(child: child!),
          home: Scaffold(
            body: Column(
              children: [
                TextField(focusNode: first, key: const Key('first')),
                TextField(focusNode: second, key: const Key('second')),
                TextFieldTapRegion(
                  child: TextButton(
                    onPressed: () => tapped++,
                    child: const Text('Accessory'),
                  ),
                ),
                TextButton(
                  onPressed: () => tapped++,
                  child: const Text('Submit'),
                ),
                const Expanded(
                  child: ColoredBox(
                    key: Key('blank'),
                    color: Colors.black,
                    child: SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('first')));
      await tester.pump();
      expect(first.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.text('Accessory'));
      await tester.pump();
      expect(first.hasFocus, isTrue);
      await tester.tap(find.byKey(const Key('second')));
      await tester.pump();
      expect(second.hasFocus, isTrue);
      await tester.tap(find.byKey(const Key('blank')));
      await tester.pump();
      expect(second.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byKey(const Key('first')));
      await tester.pump();
      await tester.tap(find.text('Submit'));
      await tester.pump();
      expect(first.hasFocus, isFalse);
      expect(tapped, 2);
    });
  }
}
