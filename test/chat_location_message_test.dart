import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_location_message.dart';

void main() {
  testWidgets(
    'long location remains actionable on a small phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1604);
      tester.view.devicePixelRatio = 2.25;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final longLocation = ChatLocation.fromJson({
        'latitudeE6': 28000001,
        'longitudeE6': 113000001,
        'coordinateSystem': 'gcj02',
        'name': List.filled(10, '测试地点长名称').join(),
        'address': List.filled(25, '测试地址详细楼栋及房间').join(),
      });
      var opened = false;
      const channel = MethodChannel('kingclub/chat-map');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        opened = true;
        expect(call.arguments['name'], longLocation.name);
        expect(call.arguments['latitudeE6'], longLocation.latitudeE6);
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.35)),
            child: child!,
          ),
          home: ChatLocationDetailsPage(location: longLocation),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('在高德地图查看'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('在高德地图查看'));
      await tester.pumpAndSettle();
      expect(opened, true);
      await tester.ensureVisible(find.text('复制地点信息'));
      await tester.pumpAndSettle();
      expect(find.text('复制地点信息').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  final location = ChatLocation.fromJson({
    'latitudeE6': 28000001,
    'longitudeE6': 113000001,
    'coordinateSystem': 'gcj02',
    'name': '测试地点',
    'address': '测试地址',
  });
  testWidgets(
    'map launch preserves coordinates and prevents duplicate launches',
    (tester) async {
      final pending = Completer<bool>();
      var calls = 0;
      const channel = MethodChannel('kingclub/chat-map');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls++;
        expect(call.method, 'open');
        expect(call.arguments, {
          'latitudeE6': 28000001,
          'longitudeE6': 113000001,
          'coordinateSystem': 'gcj02',
          'name': '测试地点',
        });
        return pending.future;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: ChatLocationDetailsPage(location: location)),
      );
      expect(calls, 0);
      await tester.tap(find.text('在高德地图查看'));
      await tester.pump();
      await tester.tap(find.text('在高德地图查看'));
      expect(calls, 1);
      SecureSessionStore.changes.add(null);
      await tester.pump();
      pending.complete(false);
      await tester.pumpAndSettle();
      expect(find.text('在高德地图查看'), findsNothing);
      expect(find.text('无法打开地图，可以复制地点信息'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  test('malformed location history remains readable without crashing', () {
    for (final value in [
      null,
      'bad',
      <String, dynamic>{},
      {1: 'bad'},
      {...location.toJson(), 'latitudeE6': 99.0},
    ]) {
      expect(ChatLocation.tryParse(value), isNull);
    }
    expect(ChatLocation.tryParse(location.toJson())!.sameAs(location), true);
  });
  testWidgets(
    'location card opens details and session changes hide private data',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ChatLocationMessage(
                  location: location,
                  mine: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          ChatLocationDetailsPage(location: location),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('测试地址'), findsOneWidget);
      await tester.tap(find.text('测试地点'));
      await tester.pumpAndSettle();
      expect(find.text('经纬度：28.000001, 113.000001'), findsOneWidget);
      expect(find.text('坐标系：GCJ-02'), findsOneWidget);
      SecureSessionStore.changes.add(null);
      await tester.pumpAndSettle();
      expect(find.text('经纬度：28.000001, 113.000001'), findsNothing);
      expect(find.text('复制地点信息'), findsNothing);
      expect(find.text('登录状态已变化，请重新进入'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
