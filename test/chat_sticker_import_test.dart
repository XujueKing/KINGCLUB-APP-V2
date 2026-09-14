import 'dart:io';

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
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
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
