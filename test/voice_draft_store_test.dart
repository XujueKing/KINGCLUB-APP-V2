import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/voice_draft_store.dart';

void main() {
  test(
    'voice drafts remain account scoped and never include old unowned files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'kingclub-voice-test-',
      );
      try {
        final a = VoiceDraftStore(root: root, account: 'member-a');
        final b = VoiceDraftStore(root: root, account: '../member-b');
        final aPath = await a.allocate(), bPath = await b.allocate();
        await File(aPath).writeAsString('synthetic a');
        await File(bPath).writeAsString('synthetic b');
        await File('${root.path}/voice_drafts/legacy.m4a')
            .writeAsString('unowned legacy');
        expect((await a.list()).map((f) => f.path), [aPath]);
        expect((await b.list()).map((f) => f.path), [bPath]);
        expect(a.owns(bPath), false);
        final reopened = VoiceDraftStore(root: root, account: 'member-a');
        expect(reopened.messageId(aPath), a.messageId(aPath));
        expect(
          a.messageId('${a.directory.path}/same.m4a'),
          isNot(b.messageId('${b.directory.path}/same.m4a')),
        );
        expect(() => b.messageId(aPath), throwsStateError);
        expect(b.owns(aPath), false);
        expect(a.owns('${root.path}/voice_drafts/legacy.m4a'), false);
        expect(a.owns('${a.directory.path}/../foreign.m4a'), false);
        expect(b.directory.absolute.path.startsWith(root.absolute.path), true);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
}
