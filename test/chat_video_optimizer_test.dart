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

  for (final missing in [true, false]) {
    test(
      'retry regenerates ${missing ? 'missing' : 'empty'} upload copy',
      () async {
        final copy = File('${directory.path}/copy.mp4');
        var prepares = 0;
        final optimizer = ChatVideoOptimizer(
          account: 'fixture',
          supported: true,
          invoke: (method, _) async {
            if (method == 'prepare') {
              prepares++;
              await copy.writeAsBytes([1, 2, 3]);
            }
            return copy.path;
          },
        );
        await optimizer.prepare(source);
        if (missing) {
          await copy.delete();
        } else {
          await copy.writeAsBytes([]);
        }
        expect((await optimizer.prepare(source)).path, copy.path);
        expect(prepares, 2);
        expect(await copy.readAsBytes(), [1, 2, 3]);
        expect(await source.length(), 4 * 1024 * 1024);
        optimizer.dispose();
      },
    );
  }

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
    expect(
      keys[0],
      'd81194beb1eaa1bcfb0be56dced5afe0132b50d5edfcfc9aabcd5f845e406fa8',
    );
    expect(keys[0], isNot(keys[1]));
  });
  test('progress uses real estimates, ignores invalid values and never moves backwards', () async {
    final pending = Completer<String?>(), reached = Completer<void>();
    final estimates = ['20', '10', 'invalid', '101', '80'];
    final values = <double>[];
    var polls = 0;
    final optimizer = ChatVideoOptimizer(
      account: 'fixture',
      supported: true,
      invoke: (method, _) async {
        if (method == 'prepare') return pending.future;
        if (method == 'progress') {
          return estimates[(polls++).clamp(0, estimates.length - 1)];
        }
        return null;
      },
    );
    final preparation = optimizer.prepare(
      source,
      onProgress: (value) {
        values.add(value);
        if (value == .8) reached.complete();
      },
    );
    await reached.future.timeout(const Duration(seconds: 10));
    pending.complete(null);
    expect(await preparation, source);
    expect(values, [.2, .8]);
  });

  test(
    'late progress after export completion cannot update the upload stage',
    () async {
      final pending = Completer<String?>(), progress = Completer<String?>();
      final polled = Completer<void>();
      final values = <double>[];
      final optimizer = ChatVideoOptimizer(
        account: 'fixture',
        supported: true,
        invoke: (method, _) {
          if (method == 'prepare') return pending.future;
          if (method == 'progress') {
            polled.complete();
            return progress.future;
          }
          return Future.value(null);
        },
      );
      final preparation = optimizer.prepare(source, onProgress: values.add);
      await polled.future.timeout(const Duration(seconds: 10));
      pending.complete(null);
      await preparation;
      progress.complete('90');
      await Future<void>.delayed(Duration.zero);
      expect(values, isEmpty);
    },
  );
}
