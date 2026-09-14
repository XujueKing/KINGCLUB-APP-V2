import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_exporter.dart';
import 'package:kingclub/src/features/messaging/data/chat_file_downloader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const reference = ChatFileReference(
    messageId: 'synthetic',
    assetId: 'synthetic',
    fileName: 'test.bin',
    size: 2,
    sha256: 'hash',
  );
  for (final scenario in ['success', 'cancel', 'revoked', 'dispose']) {
    test('system export $scenario checks permission after picker', () async {
      final calls = <String>[];
      var checks = 0;
      final exporter = ChatFileExporter();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ChatFileExporter.channel, (
            MethodCall call,
          ) async {
            calls.add(call.method);
            if (call.method == 'choose') {
              if (scenario == 'dispose') await exporter.dispose();
              return scenario != 'cancel';
            }
            if (call.method == 'copy') {
              expect(checks, 2);
              expect(call.arguments, {
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
    });
  }
}
