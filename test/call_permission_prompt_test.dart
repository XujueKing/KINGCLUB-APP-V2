import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/call_capture_permission.dart';
import 'package:kingclub/src/features/messaging/presentation/call_permission_prompt.dart';

void main() {
  for (final videoCall in [false, true]) {
    testWidgets(
      'denied call displays settings choice and never proceeds video=$videoCall',
      (tester) async {
        var proceeded = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  proceeded = await checkCallPermission(
                    context,
                    video: videoCall,
                    request: ({required bool video}) async =>
                        throw CallCapturePermissionDenied(),
                  );
                },
                child: const Text('Call'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Call'));
        await tester.pumpAndSettle();
        expect(find.text('Open Settings'), findsOneWidget);
        expect(
          find.textContaining(
            videoCall
                ? 'Enable microphone and camera access'
                : 'Enable microphone access',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(proceeded, isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
