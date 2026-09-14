import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_emoji_panel.dart';

void main() {
  testWidgets('late previous account library cannot replace current account', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.createTemp(
        'sticker-account-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      Future<Directory> library(String name) async {
        final dir = await Directory('${root.path}/$name').create();
        final image = '${dir.path}/1-0.image';
        await File(image).writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
          ),
        );
        await File('${dir.path}/library.json').writeAsString(
          jsonEncode([
            {'name': 'saved', 'images': []},
            {
              'name': name,
              'images': [image],
            },
          ]),
        );
        return dir;
      }

      final a = await library('A'), b = await library('B');
      final pendingA = Completer<Directory>();
      Widget page(String account) => MaterialApp(
        home: Scaffold(
          body: ChatEmojiPanel(
            account: account,
            libraryDirectory: (owner) =>
                owner == 'A' ? pendingA.future : Future.value(b),
            onEmoji: (_) {},
            onSticker: (_) {},
            onDelete: () {},
            onSend: () {},
          ),
        ),
      );
      await tester.pumpWidget(page('A'));
      await tester.pumpWidget(page('B'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.byTooltip('B'), findsOneWidget);
      pendingA.complete(a);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.byTooltip('A'), findsNothing);
      expect(find.byTooltip('B'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(page('A'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.byTooltip('A'), findsOneWidget);
      expect(find.byTooltip('B'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
  });
  for (final wholePack in [false, true]) {
    testWidgets('remove saved sticker persists; wholePack=$wholePack', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp(
          'sticker-remove-test-',
        );
        addTearDown(() => dir.delete(recursive: true));
        final path = '${dir.path}/1.image';
        await File(path).writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
          ),
        );
        final metadata = File('${dir.path}/library.json');
        await metadata.writeAsString(
          jsonEncode([
            {'name': 'saved', 'images': []},
            {
              'name': 'custom-pack',
              'images': [path],
            },
          ]),
        );
        Widget page() => MaterialApp(
          home: Scaffold(
            body: ChatEmojiPanel(
              account: 'A',
              libraryDirectory: (_) async => dir,
              onEmoji: (_) {},
              onSticker: (_) {},
              onDelete: () {},
              onSend: () {},
            ),
          ),
        );
        Future<void> settle() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
        }

        Future<void> hold(Finder target) async {
          final gesture = await tester.startGesture(tester.getCenter(target));
          await Future<void>.delayed(const Duration(milliseconds: 650));
          await tester.pump();
          await gesture.up();
        }

        await tester.pumpWidget(page());
        await settle();
        await tester.tap(find.byTooltip('custom-pack'));
        await tester.pumpAndSettle();
        final target = wholePack
            ? find.byTooltip('custom-pack')
            : find.byKey(ValueKey('saved-sticker-$path'));
        await hold(target);
        await tester.pumpAndSettle();
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(await File(path).exists(), isTrue);
        expect((jsonDecode(await metadata.readAsString()) as List).length, 2);
        await hold(target);
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await settle();
        expect(find.byTooltip('custom-pack'), findsNothing);
        expect(
          find.byKey(const ValueKey('add-single-sticker')),
          findsOneWidget,
        );
        expect(await File(path).exists(), isFalse);
        expect((jsonDecode(await metadata.readAsString()) as List).length, 1);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(page());
        await settle();
        expect(find.byTooltip('custom-pack'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await settle();
      });
    });
  }
}
