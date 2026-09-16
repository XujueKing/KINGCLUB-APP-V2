import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_voice_playback.dart';
import 'package:kingclub/src/features/messaging/data/voice_capture.dart';
import 'package:kingclub/src/features/messaging/data/voice_draft_store.dart';
import 'package:kingclub/src/features/messaging/presentation/voice_draft_preview.dart';

class Output implements ChatVoiceOutput {
  final events = StreamController<void>.broadcast();
  int plays = 0, stops = 0, disposals = 0;
  Completer<void>? playGate;
  @override
  Stream<void> get completed => events.stream;
  @override
  Future<void> play(String path) async {
    plays++;
    await playGate?.future;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await events.close();
  }
}

void main() {
  testWidgets('short preview completion precedes native play acknowledgement', (
    tester,
  ) async {
    final output = Output()..playGate = Completer<void>();
    final store = VoiceDraftStore(
      root: Directory.systemTemp,
      account: 'synthetic',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VoiceDraftPreview(
            draft: VoiceDraft(
              '${store.directory.path}/sample.m4a',
              const Duration(seconds: 1),
            ),
            output: output,
            loadStore: () async => store,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('播放录音'));
    await tester.pump();
    expect(output.plays, 1);
    output.events.add(null);
    await tester.pump();
    output.playGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byTooltip('播放录音'), findsOneWidget);
    expect(find.byTooltip('停止播放'), findsNothing);
    await tester.tap(find.byTooltip('播放录音'));
    await tester.pumpAndSettle();
    expect(output.plays, 2);
    output.events.add(null);
    await tester.pumpAndSettle();
    expect(find.byTooltip('播放录音'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  for (final action in ['close', 'background', 'repeat']) {
    testWidgets('pending preview authorization: $action', (tester) async {
      final output = Output();
      final store = VoiceDraftStore(
        root: Directory.systemTemp,
        account: 'synthetic',
      );
      final pending = Completer<VoiceDraftStore>();
      var requests = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceDraftPreview(
              draft: VoiceDraft(
                '${store.directory.path}/sample.m4a',
                const Duration(seconds: 2),
              ),
              output: output,
              loadStore: () {
                requests++;
                return pending.future;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('播放录音'));
      await tester.pump();
      if (action == 'close') {
        await tester.pumpWidget(const SizedBox());
      } else if (action == 'background') {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
      } else {
        await tester.tap(find.byTooltip('播放录音'));
      }
      pending.complete(store);
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(output.plays, action == 'repeat' ? 1 : 0);
      if (action == 'repeat') {
        output.events.addError(StateError('decoder failed during preview'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('播放录音'), findsOneWidget);
        expect(output.stops, greaterThan(0));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('播放录音'));
        await tester.pumpAndSettle();
        expect(output.plays, 2);
      }
      if (action == 'background') {
        expect(output.stops, greaterThan(0));
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(output.disposals, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
