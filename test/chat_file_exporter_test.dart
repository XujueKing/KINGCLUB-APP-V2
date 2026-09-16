import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_exporter.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';
import 'package:kingclub/src/features/messaging/data/chat_media_deletion.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const reference = ChatFileReference(
    messageId: 'synthetic',
    assetId: 'synthetic',
    fileName: 'test.bin',
    size: 2,
    sha256: 'hash',
  );
  for (final stage in ['choose', 'copy']) {
    test(
      'deletion cancels export during $stage and rejects late success',
      () async {
        final reached = Completer<void>();
        final pending = Completer<bool>();
        final calls = <String>[];
        final exporter = ChatFileExporter(account: 'owner');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ChatFileExporter.channel, (call) async {
              calls.add(call.method);
              if (call.method == stage) {
                reached.complete();
                return pending.future;
              }
              return call.method == 'choose' || call.method == 'copy'
                  ? true
                  : null;
            });
        addTearDown(() async {
          await exporter.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(ChatFileExporter.channel, null);
        });
        final operation = exporter.save(
          File('private.bin'),
          reference,
          () async {},
        );
        await reached.future;
        await const ChatMediaDeletion('other', false, 'synthetic').dispatch();
        await const ChatMediaDeletion('owner', true, 'synthetic').dispatch();
        expect(calls, isNot(contains('cancel')));
        await const ChatMediaDeletion('owner', false, 'synthetic').dispatch();
        expect(calls, contains('cancel'));
        pending.complete(true);
        expect(await operation, false);
        if (stage == 'choose') expect(calls, isNot(contains('copy')));
        expect(await exporter.openSaved(), false);
      },
    );
  }
  for (final scenario in ['success', 'cancel', 'revoked', 'dispose']) {
    test('system export $scenario checks permission after picker', () async {
      final calls = <String>[];
      var checks = 0;
      String? operationId;
      final exporter = ChatFileExporter();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ChatFileExporter.channel, (
            MethodCall call,
          ) async {
            calls.add(call.method);
            final id = (call.arguments as Map)['operationId'];
            expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
            operationId ??= id as String;
            expect(id, operationId);
            if (call.method == 'choose') {
              if (scenario == 'dispose') await exporter.dispose();
              return scenario != 'cancel';
            }
            if (call.method == 'copy') {
              expect(checks, 2);
              expect(call.arguments, {
                'operationId': (call.arguments as Map)['operationId'],
                'path': 'private.bin',
                'size': 2,
                'sha256': 'hash',
              });
              return true;
            }
            return null;
          });
      addTearDown(() async {
        await exporter.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ChatFileExporter.channel, null);
      });
      final operation = exporter.save(File('private.bin'), reference, () async {
        checks++;
        if (scenario == 'revoked' && checks == 2) throw StateError('revoked');
      });
      if (scenario == 'revoked') {
        await expectLater(operation, throwsStateError);
      } else {
        expect(await operation, scenario == 'success');
      }
      expect(calls.contains('copy'), scenario == 'success');
      if (scenario != 'success') expect(calls.contains('cancel'), true);
      final beforeOpen = calls.length;
      await exporter.openSaved();
      expect(calls.length, beforeOpen + (scenario == 'success' ? 1 : 0));
      if (scenario == 'success') expect(calls.last, 'openSaved');
      await exporter.dispose();
      final afterDispose = calls.length;
      expect(await exporter.openSaved(), false);
      expect(calls.length, afterDispose);
    });
  }
}
