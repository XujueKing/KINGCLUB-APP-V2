import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/data/chat_map_preview_cache.dart';
import 'package:kingclub/src/features/messaging/presentation/deferred_chat_map.dart';

void main() {
  testWidgets(
    'snapshot is shared by coordinates and late images are discarded after session change',
    (tester) async {
      const channel = MethodChannel('kingclub/chat-map-preview');
      var requests = 0;
      final response = Completer<Uint8List>();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        _,
      ) {
        requests++;
        return response.future;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final location = ChatLocation.fromJson({
        'latitudeE6': 27012345,
        'longitudeE6': 113012345,
        'coordinateSystem': 'wgs84',
        'name': 'Synthetic location',
      });
      final card = ChatMapPreviewCache.load(location);
      final detail = ChatMapPreviewCache.load(location);
      expect(identical(card, detail), isTrue);
      await tester.pump();
      expect(requests, 1);
      SecureSessionStore.changes.add(null);
      await tester.pump();
      response.complete(Uint8List.fromList([1, 2, 3]));
      await tester.pump();
      expect(await card, isNull);
      expect(await ChatMapPreviewCache.load(location), isNotNull);
      expect(requests, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native map waits for route slide and stays revealed while selecting another point',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const SizedBox()),
      );
      unawaited(
        navigator.currentState!.push(
          PageRouteBuilder<void>(
            transitionDuration: const Duration(milliseconds: 300),
            pageBuilder: (_, _, _) => ValueListenableBuilder<bool>(
              valueListenable: ready,
              builder: (_, loaded, _) => DeferredChatMap(
                ready: loaded,
                map: const ColoredBox(
                  key: ValueKey('native'),
                  color: Colors.blue,
                ),
                placeholder: const ColoredBox(
                  key: ValueKey('preview'),
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('native')), findsNothing);
      expect(find.byKey(const ValueKey('preview')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('native')), findsOneWidget);
      ready.value = true;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview')), findsNothing);
      ready.value = false;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
