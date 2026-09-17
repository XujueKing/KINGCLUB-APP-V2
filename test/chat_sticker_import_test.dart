import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_emoji_panel.dart';

class Picked extends XFile {
  Picked({this.fail = false, this.large = false}) : super('synthetic');
  final bool fail, large;
  int writes = 0;
  @override
  Future<int> length() async => large ? 20 * 1024 * 1024 + 1 : 3;
  @override
  Future<void> saveTo(String path) async {
    writes++;
    await File(path).writeAsBytes([1, 2, 3]);
    if (fail) throw StateError('interrupted copy');
  }
}

void main() {
  for (final scenario in [
    (counts: [200], pack: false, allowed: false, message: '每个表情分类最多200张'),
    (counts: [100, 200, 200], pack: false, allowed: false, message: '最多收藏500张'),
    (
      counts: List.filled(20, 1),
      pack: true,
      allowed: false,
      message: '最多添加20个表情分类',
    ),
    (counts: [199], pack: false, allowed: true, message: ''),
    (counts: [99, 200, 200], pack: false, allowed: true, message: ''),
    (counts: List.filled(19, 1), pack: true, allowed: true, message: ''),
  ]) {
    testWidgets('import capacity ${scenario.counts} pack=${scenario.pack}', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('sticker-capacity-');
        addTearDown(() => dir.delete(recursive: true));
        final image = File('${dir.path}/keep.image');
        await image.writeAsBytes(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
          ),
        );
        final before = jsonEncode([
          for (var i = 0; i < scenario.counts.length; i++)
            {
              'name': i == 0 ? '添加的单个表情' : 'pack-$i',
              'images': List.filled(scenario.counts[i], image.path),
            },
        ]);
        final journal = File('${dir.path}/library.json');
        await journal.writeAsString(before);
        final selected = Picked();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatEmojiPanel(
                account: 'synthetic',
                libraryDirectory: (_) async => dir,
                pickImages: () async => [selected],
                onEmoji: (_) {},
                onSticker: (_) {},
                onDelete: () {},
                onSend: () {},
              ),
            ),
          ),
        );
        Future<void> settle() async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pump();
        }

        await settle();
        if (scenario.pack) {
          await tester.tap(find.byTooltip('添加表情包'));
          await settle();
          await tester.enterText(find.byType(TextField), 'new-pack');
          await tester.tap(find.text('添加'));
        } else {
          await tester.tap(find.byTooltip('添加的单个表情'));
          await tester.pump();
          await tester.tap(find.byKey(const ValueKey('add-single-sticker')));
        }
        await settle();
        if (scenario.allowed) {
          // Real filesystem writes can outlast a fixed 200 ms under parallel
          // builds. Wait for the durable commit, retaining a bounded failure.
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (await journal.readAsString() == before &&
              DateTime.now().isBefore(deadline)) {
            await settle();
          }
        } else {
          await settle();
        }
        expect(selected.writes, scenario.allowed ? 1 : 0);
        if (scenario.allowed) {
          final next = jsonDecode(await journal.readAsString()) as List;
          final count = next.fold<int>(
            0,
            (n, p) => n + (p['images'] as List).length,
          );
          expect(count, scenario.counts.fold<int>(0, (a, b) => a + b) + 1);
          expect(next.length, scenario.counts.length + (scenario.pack ? 1 : 0));
        } else {
          expect(await journal.readAsString(), before);
          expect((await dir.list().toList()).length, 2);
          expect(find.textContaining(scenario.message), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
  for (final large in [false, true]) {
    testWidgets('failed sticker import cleans only new copies large=$large', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('sticker-import-');
        addTearDown(() => dir.delete(recursive: true));
        final existing = File('${dir.path}/keep.image');
        await existing.writeAsBytes([9]);
        final journal = File('${dir.path}/library.json');
        await journal.writeAsString('[{"name":"saved","images":[]}]');
        final first = Picked(), second = Picked(fail: !large, large: large);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChatEmojiPanel(
                account: 'synthetic',
                libraryDirectory: (_) async => dir,
                pickImages: () async => [first, second],
                onEmoji: (_) {},
                onSticker: (_) {},
                onDelete: () {},
                onSend: () {},
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.tap(find.byTooltip('添加的单个表情'));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('add-single-sticker')));
        await tester.pump();
        final add = find.byKey(const ValueKey('add-single-sticker'));
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (tester.widget<InkWell>(add).onTap == null &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
        // The control is re-enabled only after rollback has completed.
        expect(tester.widget<InkWell>(add).onTap, isNotNull);
        expect(first.writes, 1);
        expect(second.writes, large ? 0 : 1);
        expect((await dir.list().toList()).length, 2);
        expect(await existing.readAsBytes(), [9]);
        expect(await journal.readAsString(), '[{"name":"saved","images":[]}]');
        await tester.pumpWidget(const SizedBox());
      });
    });
  }
}
