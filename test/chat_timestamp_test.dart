import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_timestamp.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';

import 'direct_chat_controller_test.dart' as fixture;

void main() {
  test('timestamp gaps, local calendar boundaries and malformed dates', () {
    final now = DateTime(2026, 9, 16, 12);
    String? label(String? current, [String? previous]) =>
        chatTimestampLabel(current, previous, now: now);
    expect(label('2026-09-16T10:03:00'), '今天 10:03');
    expect(label('2026-09-16T10:04:59', '2026-09-16T10:00:00'), isNull);
    expect(label('2026-09-16T10:05:00', '2026-09-16T10:00:00'), '今天 10:05');
    expect(label('2026-09-16T00:00:01', '2026-09-15T23:59:59'), '今天 00:00');
    expect(label('2026-09-15T23:59:59'), '昨天 23:59');
    expect(label('2026-09-12T09:08:00'), '9月12日 09:08');
    expect(label('2025-09-12T09:08:00'), '2025年9月12日 09:08');
    expect(label(null), isNull);
    expect(label('invalid'), isNull);
    expect(label('2026-09-16T10:03:00', 'invalid'), '今天 10:03');
    expect(
      label(DateTime(2026, 9, 16, 10, 3).toUtc().toIso8601String()),
      '今天 10:03',
    );
  });
  testWidgets(
    'real history renders first and spaced times above message rows',
    (tester) async {
      final repo = MessagingRepository(
        account: 'me',
        call: (id, _) async {
          if (id == 'K260913000604') {
            return fixture.history([
              for (final i in [0, 1, 2])
                {
                  ...fixture.ack({
                    'clientMessageId': 'm$i',
                    'text': 'message $i',
                  }, sequence: i + 1),
                  'createdDate': DateTime(
                    2020,
                    1,
                    2,
                    10,
                    i == 2 ? 7 : i,
                  ).toUtc().toIso8601String(),
                },
            ]);
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            repository: repo,
            chatOutbox: fixture.MemoryOutbox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2020年1月2日 10:00'), findsOneWidget);
      expect(find.text('2020年1月2日 10:01'), findsNothing);
      expect(find.text('2020年1月2日 10:07'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('2020年1月2日 10:07')).dy,
        lessThan(tester.getTopLeft(find.text('message 2')).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
