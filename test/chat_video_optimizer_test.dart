import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_video_optimizer.dart';

void main() {
  late Directory directory;
  late File source;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'kingclub-video-optimizer-',
    );
    source = File('${directory.path}/source.mp4');
    await source.writeAsBytes(List.filled(4 * 1024 * 1024, 7));
  });
  tearDown(() async => directory.delete(recursive: true));

  test('small videos skip bridge and leave source unchanged', () async {
    await source.writeAsBytes([1, 2, 3]);
    final optimizer = ChatVideoOptimizer(
      account: 'fixture',
      supported: true,
      invoke: (_, _) async => throw StateError('must not transcode'),
    );
    expect(await optimizer.prepare(source), source);
    expect(await source.readAsBytes(), [1, 2, 3]);
  });

  test(
    'smaller upload copy is reused on retry and released only after queueing',
    () async {
      final copy = await File('${directory.path}/copy.mp4')
          .writeAsBytes([1, 2, 3]);
      final calls = <String>[];
      final optimizer = ChatVideoOptimizer(
        account: 'fixture',
        supported: true,
        invoke: (method, args) async {
          calls.add(method);
          return copy.path;
        },
      );
      expect((await optimizer.prepare(source)).path, copy.path);
      expect((await optimizer.prepare(source)).path, copy.path);
      expect(calls, ['prepare']);
      expect(await source.length(), 4 * 1024 * 1024);
      await optimizer.acknowledgeQueued();
      expect(calls, ['prepare', 'release']);
    },
  );

  test('native failure preserves original upload source', () async {
    final optimizer = ChatVideoOptimizer(
      account: 'fixture',
      supported: true,
      invoke: (_, _) async => throw PlatformException(code: 'unsupported'),
    );
    expect(await optimizer.prepare(source), source);
  });

  test('larger output does not replace original', () async {
    final copy = await File('${directory.path}/copy.mp4')
        .writeAsBytes(List.filled(5 * 1024 * 1024, 8));
    final optimizer = ChatVideoOptimizer(
      account: 'fixture',
      supported: true,
      invoke: (_, _) async => copy.path,
    );
    expect(await optimizer.prepare(source), source);
  });

  test('leaving during native processing rejects late completion', () async {
    final started = Completer<void>(), pending = Completer<String?>();
    final calls = <String>[];
    final optimizer = ChatVideoOptimizer(
      account: 'fixture',
      supported: true,
      invoke: (method, _) {
        calls.add(method);
        if (method == 'prepare') {
          started.complete();
          return pending.future;
        }
        return Future.value(null);
      },
    );
    final prepare = optimizer.prepare(source);
    await started.future;
    optimizer.dispose();
    final rejected = expectLater(prepare, throwsStateError);
    pending.complete(null);
    await rejected;
    expect(calls, ['prepare', 'cancel']);
  });

  test('cache identity includes member account and source bytes', () async {
    final keys = <String>[];
    for (final account in ['first', 'second']) {
      final optimizer = ChatVideoOptimizer(
        account: account,
        supported: true,
        invoke: (_, args) async {
          keys.add(args['key'] as String);
          return null;
        },
      );
      await optimizer.prepare(source);
    }
    expect(keys[0], isNot(keys[1]));
  });
}
