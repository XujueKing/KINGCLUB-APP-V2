import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/data/chat_location_lookup.dart';
import 'package:kingclub/src/features/messaging/data/chat_place_search.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_location_picker_page.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';

ChatLocation point(String name, int lat) => ChatLocation.fromJson({
  'latitudeE6': lat,
  'longitudeE6': 113000000,
  'coordinateSystem': 'wgs84',
  'name': name,
  'address': 'Test address',
});

class Gps implements ChatLocationLookup {
  @override
  Future<ChatLocation> current() async => point('当前位置', 28000000);
  @override
  Future<List<ChatLocation>> search(String q) async => [];
}

class Places implements ChatPlaceSearch {
  bool fails = false;
  Completer<List<ChatLocation>>? pending;
  int cancellations = 0;
  @override
  Future<List<ChatLocation>> nearby(ChatLocation p) async {
    if (fails) throw StateError('query rejected');
    if (pending != null) return pending!.future;
    return [point('Building A', 28000100), point('Shop B', 28000200)];
  }

  @override
  Future<List<ChatLocation>> search(String q, ChatLocation? p) async => [];
  @override
  void cancel() {
    cancellations++;
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'session change cancels POI lookup and rejects its late results',
    (tester) async {
      final places = Places()..pending = Completer<List<ChatLocation>>();
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(lookup: Gps(), places: places),
        ),
      );
      await tester.tap(find.byTooltip('使用当前位置'));
      await tester.pump();
      final prior = places.cancellations;
      SecureSessionStore.changes.add(null);
      await tester.pump();
      expect(places.cancellations, greaterThan(prior));
      places.pending!.complete([point('Late private place', 28000300)]);
      await tester.pumpAndSettle();
      expect(find.text('Late private place'), findsNothing);
      expect(find.text('当前位置'), findsNothing);
      expect(find.text('登录状态已变化，请重新进入'), findsOneWidget);
    },
  );
  testWidgets(
    'nearby list allows explicit building choice without sending GPS automatically',
    (tester) async {
      ChatLocation? saved, sent;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: Gps(),
            places: Places(),
            onSelectionChanged: (p) async => saved = p,
            onConfirm: (p) async => sent = p,
          ),
        ),
      );
      await tester.tap(find.byTooltip('使用当前位置'));
      await tester.pumpAndSettle();
      expect(find.text('当前位置'), findsOneWidget);
      expect(find.text('Building A'), findsOneWidget);
      expect(sent, isNull);
      await tester.scrollUntilVisible(
        find.text('Shop B'),
        80,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Shop B'));
      await tester.pumpAndSettle();
      expect(saved!.latitudeE6, 28000200);
      expect(sent, isNull);
      await tester.tap(find.text('发送'));
      await tester.pumpAndSettle();
      expect(sent!.sameAs(point('Shop B', 28000200)), isTrue);
    },
  );
  testWidgets(
    'failed POI query keeps actual GPS choice with visible retry guidance',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: Gps(),
            places: Places()..fails = true,
          ),
        ),
      );
      await tester.tap(find.byTooltip('使用当前位置'));
      await tester.pumpAndSettle();
      expect(find.text('当前位置'), findsOneWidget);
      expect(find.text('附近地点查询失败，可以重新定位或搜索'), findsOneWidget);
      expect(find.text('Building A'), findsNothing);
    },
  );
}
