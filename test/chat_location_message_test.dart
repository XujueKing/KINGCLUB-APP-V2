import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:kingclub/src/features/messaging/data/chat_location.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_location_message.dart';

void main() {
  final location = ChatLocation.fromJson({
    'latitudeE6': 28000001,
    'longitudeE6': 113000001,
    'coordinateSystem': 'gcj02',
    'name': '测试地点',
    'address': '测试地址',
  });
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
