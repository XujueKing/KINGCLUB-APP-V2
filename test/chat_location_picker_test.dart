import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/data/chat_location_lookup.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_location_picker_page.dart';

final place = ChatLocation.fromJson({
  'latitudeE6': 28000000,
  'longitudeE6': 113000000,
  'coordinateSystem': 'wgs84',
  'name': 'Synthetic place',
  'address': 'Synthetic address',
});

class Lookup implements ChatLocationLookup {
  int currentCalls = 0;
  Completer<List<ChatLocation>>? pending;
  @override
  Future<ChatLocation> current() async {
    currentCalls++;
    return place;
  }

  @override
  Future<List<ChatLocation>> search(String query) async =>
      pending == null ? [place] : await pending!.future;
}

void main() {
  testWidgets(
    'map preview preserves WGS84 and never selects or sends a location',
    (tester) async {
      const maps = MethodChannel('kingclub/chat-map');
      var opened = 0, sent = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(maps, (
        call,
      ) async {
        opened++;
        expect(call.arguments['latitudeE6'], place.latitudeE6);
        expect(call.arguments['longitudeE6'], place.longitudeE6);
        expect(call.arguments['coordinateSystem'], 'wgs84');
        expect(call.arguments['mode'], 'view');
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          maps,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: Lookup(),
            onConfirm: (_) async => sent++,
          ),
        ),
      );
      await tester.tap(find.text('使用当前位置'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('在系统地图中查看'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(sent, 0);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'location is requested explicitly and choosing never sends without confirmation',
    (tester) async {
      final lookup = Lookup();
      var sent = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: lookup,
            onConfirm: (selected) async {
              expect(selected.sameAs(place), true);
              sent++;
              throw StateError('offline');
            },
          ),
        ),
      );
      expect(lookup.currentCalls, 0);
      await tester.tap(find.text('使用当前位置'));
      await tester.pumpAndSettle();
      expect(lookup.currentCalls, 1);
      expect(sent, 0);
      await tester.tap(find.text('Synthetic place'));
      await tester.pump();
      expect(sent, 0);
      await tester.tap(find.text('确认发送此位置'));
      await tester.pumpAndSettle();
      expect(sent, 1);
      expect(find.text('发送未完成，请重试'), findsOneWidget);
      expect(find.text('Synthetic place'), findsOneWidget);
    },
  );
  testWidgets(
    'session invalidation rejects a late search result and disables sending',
    (tester) async {
      final lookup = Lookup()..pending = Completer<List<ChatLocation>>();
      await tester.pumpWidget(
        MaterialApp(home: ChatLocationPickerPage(lookup: lookup)),
      );
      await tester.enterText(find.byType(TextField), 'Synthetic');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      SecureSessionStore.changes.add(null);
      await tester.pump();
      lookup.pending!.complete([place]);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic place'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    },
  );
}
