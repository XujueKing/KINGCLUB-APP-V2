import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/data/chat_location_lookup.dart';
import 'package:kingclub/src/features/messaging/data/chat_place_search.dart';
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

class PrecisePlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;
  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;
}

class MapOnlyLookup extends NativeChatLocationLookup {
  @override
  Future<ChatLocation> current() async =>
      throw StateError('Independent GPS must not be used');
  @override
  Future<ChatLocation> currentCoordinate() async =>
      throw StateError('Independent GPS must not be used');
}

class BoundaryPlaces implements ChatPlaceSearch {
  ChatLocation? queried;
  @override
  Future<List<ChatLocation>> nearby(ChatLocation value) async {
    queried = value;
    return [
      ChatLocation.fromJson({...value.toJson(), 'name': 'Tencent residence'}),
    ];
  }

  @override
  Future<List<ChatLocation>> search(String text, ChatLocation? value) async =>
      [];
  @override
  void cancel() {}
  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'mainland native coordinates leave as WGS and reenter as one GCJ candidate',
    (tester) async {
      final original = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = PrecisePlatform();
      final places = BoundaryPlaces();
      Map<String, dynamic>? centered;
      MethodChannel? channel;
      final native = {
        'latitudeE6': 39901404,
        'longitudeE6': 116406243,
        'coordinateSystem': 'gcj02',
        'name': '当前位置',
        'address': '',
      };
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (call) async {
          if (call.method == 'create') {
            channel = MethodChannel(
              'kingclub/location-picker-map/${call.arguments['id']}',
            );
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel!,
              (call) async {
                if (call.method == 'locate') {
                  return {'location': native, 'accuracyMeters': 8};
                }
                if (call.method == 'center') {
                  centered = Map<String, dynamic>.from(call.arguments);
                  return 'gcj02';
                }
                return null;
              },
            );
          }
          return null;
        },
      );
      addTearDown(() {
        GeolocatorPlatform.instance = original;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
        if (channel != null) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel!,
            null,
          );
        }
      });
      ChatLocation? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ChatLocationPickerPage(
            lookup: MapOnlyLookup(),
            places: places,
            onSelectionChanged: (value) async => saved = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(places.queried!.coordinateSystem, 'wgs84');
      expect(places.queried!.latitudeE6, closeTo(39900000, 3));
      expect(places.queried!.longitudeE6, closeTo(116400000, 3));
      await tester.tap(find.text('Tencent residence'));
      await tester.pumpAndSettle();
      expect(saved!.coordinateSystem, 'wgs84');
      expect(centered!['latitudeE6'], saved!.latitudeE6);
      final display = centered!['alternateGCJ02'] as Map;
      expect(display['coordinateSystem'], 'gcj02');
      expect(display['latitudeE6'], closeTo(native['latitudeE6'] as int, 2));
      expect(display['longitudeE6'], closeTo(native['longitudeE6'] as int, 2));
      await tester.pumpWidget(const SizedBox());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  for (final cachedGps in [true, false]) {
    testWidgets(
      'restored ${cachedGps ? 'GPS' : 'manual'} draft queries places and respects map authority',
      (tester) async {
        final original = GeolocatorPlatform.instance;
        GeolocatorPlatform.instance = PrecisePlatform();
        addTearDown(() => GeolocatorPlatform.instance = original);
        final cached = ChatLocation.fromJson({
          ...place.toJson(),
          'name': cachedGps ? '当前位置' : '原手动选择',
        });
        final live = ChatLocation.fromJson({
          ...place.toJson(),
          'latitudeE6': 28010000,
          'name': '当前位置',
        });
        final poi = ChatLocation.fromJson({
          ...place.toJson(),
          'name': 'Nearby real candidate',
        });
        MethodChannel? channel;
        var locateCalls = 0, nearbyCalls = 0, saved = 0, sent = 0;
        ChatLocation? queried;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          (call) async {
            if (call.method == 'create') {
              channel = MethodChannel(
                'kingclub/location-picker-map/${call.arguments['id']}',
              );
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                channel!,
                (call) async {
                  if (call.method == 'locate') {
                    locateCalls++;
                    return {'location': live.toJson(), 'accuracyMeters': 12};
                  }
                  if (call.method == 'nearby') {
                    nearbyCalls++;
                    queried = ChatLocation.fromJson(
                      Map<String, dynamic>.from(call.arguments),
                    );
                    return [queried!.toJson(), poi.toJson()];
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
          if (channel != null) {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel!,
              null,
            );
          }
        });
        await tester.pumpWidget(
          MaterialApp(
            home: ChatLocationPickerPage(
              lookup: MapOnlyLookup(),
              initialSelection: cached,
              onSelectionChanged: (_) async => saved++,
              onConfirm: (_) async => sent++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(locateCalls, cachedGps ? 1 : 0);
        expect(nearbyCalls, 1);
        expect(queried!.sameAs(cachedGps ? live : cached), true);
        expect(find.text('Nearby real candidate'), findsOneWidget);
        expect(
          saved,
          cachedGps ? 1 : 0,
          reason:
              'Restoring a manual draft must preserve its durable message ID',
        );
        expect(sent, 0);
        // The map's projected point can differ from the Flutter box center
        // (for example, MapKit's safe-area camera inset). It must remain a
        // visual update without saving or sending a different location.
        final savedBeforeProjection = saved;
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          channel!.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('selectionAnchor', {'x': 180.0, 'y': 260.0}),
          ),
          (_) {},
        );
        await tester.pump();
        final pin = find.byIcon(Icons.location_on);
        expect(tester.getTopLeft(pin), const Offset(153, 210.5));
        expect(saved, savedBeforeProjection);
        expect(sent, 0);
        expect(queried!.sameAs(cachedGps ? live : cached), true);
        await tester.pumpWidget(const SizedBox());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

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
