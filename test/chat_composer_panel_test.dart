import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
void main() {
 testWidgets('composer opens emoji picker and inserts selected emoji', (tester) async {
  tester.view.devicePixelRatio = 1; tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetDevicePixelRatio); addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('direct-chat-emoji'))); await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('direct-chat-emoji-panel')), findsOneWidget);
  await tester.tap(find.text('😀').first); await tester.pump();
  final field = tester.widget<TextField>(find.byKey(const ValueKey('direct-chat-input')));
  expect(field.controller!.text, '😀');
  await tester.tap(find.byTooltip('删除表情')); await tester.pump();
  expect(field.controller!.text, '');
  await tester.tap(find.byKey(const ValueKey('direct-chat-attachments'))); await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('direct-chat-emoji-panel')), findsNothing);
  expect(find.byKey(const ValueKey('direct-chat-attachment-panel')), findsOneWidget);
  expect(tester.takeException(), isNull);
 });
}
