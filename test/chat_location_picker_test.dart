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
    'native map dragging changes selection but never sends; stale results are rejected',
    (tester) async {
      MethodChannel? map;
      Completer<List<Map<String, dynamic>>>? pending;
      var sent = 0;
      final picked = ChatLocation.fromJson({
        ...place.toJson(),
        'latitudeE6': 28002000,
        'name': '地图选点',
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async {
          if (call.method == 'create') {
            map = MethodChannel(
              'kingclub/location-picker-map/${call.arguments['id']}',
            );
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              map!,
              (call) async {
                if (call.method == 'nearby') {
                  return pending?.future ??
                      [
                        ChatLocation.fromJson(
                          Map<String, dynamic>.from(call.arguments),
                        ).toJson(),
                      ];
                }
                return null;
              },
            );
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
        if (map != null) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            map!,
            null,
          );
        }
      });
      Future<void> event(String method, [dynamic args]) async {
        final done = Completer<void>();
        tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          map!.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, args),
          ),
          (_) => done.complete(),
        );
        await done.future;
      }

      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: Lookup(),
            onConfirm: (_) async => sent++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(map, isNotNull);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(sent, 0);
      await event('moving');
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await event('centerChanged', picked.toJson());
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('地图选点'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(sent, 0);
      pending = Completer<List<Map<String, dynamic>>>();
      await event('moving');
      await event('centerChanged', place.toJson());
      await tester.pump(const Duration(milliseconds: 400));
      SecureSessionStore.changes.add(null);
      await tester.pump();
      pending.complete([place.toJson()]);
      await tester.pumpAndSettle();
      expect(find.text('Synthetic place'), findsNothing);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(sent, 0);
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'small phone keeps cancel and send reachable while search keyboard is open',
    (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: Lookup(),
            initialSelection: place,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('取消').hitTestable(), findsOneWidget);
      expect(find.text('发送').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

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
      await tester.tap(find.byTooltip('使用当前位置'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('在系统地图中查看'));
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
      await tester.tap(find.byTooltip('使用当前位置'));
      await tester.pumpAndSettle();
      expect(lookup.currentCalls, 1);
      expect(sent, 0);
      await tester.tap(find.text('Synthetic place'));
      await tester.pump();
      expect(sent, 0);
      await tester.tap(find.text('发送'));
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
