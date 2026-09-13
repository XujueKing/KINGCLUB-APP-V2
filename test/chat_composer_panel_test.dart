import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
void main() {
 testWidgets('hold overlay highlights cancel and dismisses on release', (tester) async {
  tester.view.devicePixelRatio = 1; tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetDevicePixelRatio); addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('direct-chat-microphone'))); await tester.pumpAndSettle();
  final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('direct-chat-hold-to-talk'))));
  await tester.pump(const Duration(milliseconds: 16));
  expect(find.text('松手发送'), findsOneWidget);
  await gesture.moveBy(const Offset(-100, -100)); await tester.pump(const Duration(milliseconds: 180));
  expect(find.text('松开取消'), findsOneWidget);
  await gesture.up(); await tester.pumpAndSettle();
  expect(find.text('松开取消'), findsNothing);
  expect(tester.takeException(), isNull);
 });
 testWidgets('microphone expands and returns to text without losing draft', (tester) async {
  tester.view.devicePixelRatio = 1; tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetDevicePixelRatio); addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(MaterialApp(theme: KingTheme.dark, home: const DirectChatPage()));
  await tester.pumpAndSettle();
  final input = find.byKey(const ValueKey('direct-chat-input'));
  await tester.enterText(input, 'draft');
  await tester.tap(find.byKey(const ValueKey('direct-chat-microphone')));
  await tester.pump();
  final surface = find.byKey(const ValueKey('direct-chat-voice-surface'));
  final initialWidth = tester.getSize(surface).width;
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.getSize(surface).width, greaterThan(initialWidth));
  await tester.pumpAndSettle();
  expect(find.text('按住 说话'), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('direct-chat-text-mode'))); await tester.pumpAndSettle();
  expect(tester.widget<TextField>(input).controller!.text, 'draft');
  expect(tester.takeException(), isNull);
 });
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
