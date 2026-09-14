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
}
