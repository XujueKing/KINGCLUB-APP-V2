import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_location_draft.dart';
import 'package:kingclub/src/features/messaging/data/chat_text_draft_store.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_location_picker_page.dart';

import 'chat_location_picker_test.dart' show Lookup, place;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  ChatLocationDraftStore store([
    String account = 'a',
    String target = 'peer:b',
  ]) => ChatLocationDraftStore(
    ChatTextDraftStore(account, 'location:$target', () async {}),
  );
  test('location selection survives reopen and stale cleanup preserves replacement', () async {
    final first = await store().save(place);
    final restored = (await store().read())!;
    expect(restored.id, first.id);
    expect(restored.location.sameAs(place), true);
    expect(await store('b').read(), isNull);
    expect(await store('a', 'group:b').read(), isNull);
    final second = await store().save(place);
    await store().remove(first.id);
    expect((await store().read())!.id, second.id);
    await store().remove(second.id);
    expect(await store().read(), isNull);
  });
  testWidgets(
    'restored selection does not acquire location or send automatically',
    (tester) async {
      final lookup = Lookup();
      var sent = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: lookup,
            initialSelection: place,
            onConfirm: (_) async {
              sent++;
              throw StateError('offline');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(lookup.currentCalls, 0);
      expect(sent, 0);
      expect(find.text(place.name), findsOneWidget);
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed!();
      await tester.pumpAndSettle();
      expect(sent, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'confirmation waits for durable selection and remains disabled on failure',
    (tester) async {
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: Lookup(),
            onSelectionChanged: (_) => pending.future,
          ),
        ),
      );
      final current = tester.widget<ListTile>(find.byType(ListTile).first);
      current.onTap!();
      await tester.pumpAndSettle();
      await tester.tap(find.text(place.name));
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.completeError(StateError('disk unavailable'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
