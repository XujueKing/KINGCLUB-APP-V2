import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/src/features/messaging/presentation/legacy_messaging_components.dart';

void main() {
  testWidgets('plus menu dismisses and routes friend and scan separately', (
    tester,
  ) async {
    var friends = 0;
    var scans = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: LegacyConversationTabs(
              chatSelected: true,
              onChat: () {},
              onContacts: () {},
              onAdd: () => friends++,
              onScan: () => scans++,
            ),
          ),
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.byTooltip('添加好友'));
      await tester.pumpAndSettle();
      expect(find.text('发起群聊'), findsOneWidget);
      expect(find.text('收付款'), findsNothing);
    }

    await open();
    expect(friends, 0);
    await tester.tapAt(const Offset(20, 300));
    await tester.pumpAndSettle();
    expect(find.text('扫一扫'), findsNothing);
    await open();
    await tester.tap(find.text('添加朋友'));
    await tester.pumpAndSettle();
    expect(friends, 1);
    expect(scans, 0);
    await open();
    await tester.tap(find.text('扫一扫'));
    await tester.pumpAndSettle();
    expect(scans, 1);
    expect(find.text('扫一扫'), findsNothing);
  });
}
