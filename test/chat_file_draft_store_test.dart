import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_draft_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('draft survives reopen, scopes account and target, stale removal preserves replacement', () async {
    final root = await Directory.systemTemp.createTemp('draft-store-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = await File('${root.path}/source')
        .writeAsBytes(List.generate(65537, (i) => i % 251));
    ChatFileDraftStore store([
      String account = 'a',
      String target = 'peer:b',
    ]) => ChatFileDraftStore(
      account: account,
      target: target,
      checkSession: () async {},
      directory: () async => root,
    );
    final first = await store().save(source, 'first.bin');
    final reopened = await store().read();
    expect(reopened!.id, first.id);
    expect(await reopened.file.readAsBytes(), await source.readAsBytes());
    expect(await store('other').read(), isNull);
    expect(await store('a', 'group:b').read(), isNull);
    final second = await store().save(source, 'second.bin');
    await store().remove(first.id);
    expect((await store().read())!.id, second.id);
    expect(await first.file.exists(), false);
    await second.file.writeAsBytes([1]);
    await expectLater(store().read(), throwsStateError);
    await store().remove(second.id);
    expect(await store().read(), isNull);
  });
  test('recovery removes only old unreferenced files in this target', () async {
    final root = await Directory.systemTemp.createTemp('draft-prune-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = await File('${root.path}/source').writeAsBytes([1, 2]);
    ChatFileDraftStore store(String target) => ChatFileDraftStore(
      account: 'a',
      target: target,
      directory: () async => root,
      checkSession: () async {},
    );
    final active = await store('one').save(source, 'active.bin');
    final other = await store('two').save(source, 'other.bin');
    final old = DateTime.now().subtract(const Duration(days: 2));
    await active.file.setLastModified(old);
    await other.file.setLastModified(old);
    final orphan = await File(
      '${active.file.parent.path}/11111111-1111-1111-1111-111111111111.bin',
    ).writeAsBytes([3]);
    await orphan.setLastModified(old);
    final recent = await File(
      '${active.file.parent.path}/22222222-2222-2222-2222-222222222222.bin',
    ).writeAsBytes([4]);
    final unrelated = await File('${active.file.parent.path}/other.txt')
        .writeAsBytes([5]);
    await unrelated.setLastModified(old);
    expect((await store('one').read())!.id, active.id);
    expect(await orphan.exists(), false);
    expect(await active.file.exists(), true);
    expect(await other.file.exists(), true);
    expect(await recent.exists(), true);
    expect(await unrelated.exists(), true);
  });
  test('session loss during copy does not publish a draft', () async {
    final root = await Directory.systemTemp.createTemp('draft-session-test-');
    addTearDown(() => root.delete(recursive: true));
    final source = await File('${root.path}/source').writeAsBytes([1, 2, 3]);
    var checks = 0;
    final store = ChatFileDraftStore(
      account: 'a',
      target: 'b',
      directory: () async => root,
      checkSession: () async {
        if (++checks == 2) throw StateError('session changed');
      },
    );
    await expectLater(store.save(source, 'x.bin'), throwsStateError);
    final fresh = ChatFileDraftStore(
      account: 'a',
      target: 'b',
      directory: () async => root,
      checkSession: () async {},
    );
    expect(await fresh.read(), isNull);
    final files = await Directory('${root.path}/chat-file-drafts')
        .list(recursive: true)
        .where((e) => e is File)
        .toList();
    expect(files, isEmpty);
  });
}
