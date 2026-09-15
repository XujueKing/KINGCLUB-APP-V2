import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_page.dart';
import 'package:kingclub/src/features/messaging/presentation/direct_chat_details_page.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';

import 'direct_chat_controller_test.dart' show MemoryOutbox, history;

void main() {
  testWidgets(
    'chat title follows current remark and restores nickname when cleared',
    (tester) async {
      var remark = 'New remark';
      var profiles = 0;
      final repo = MessagingRepository(
        account: 'me',
        call: (method, _) async {
          if (method == 'K260913000604') {
            return {
              ...history([]),
              'settings': {'remark': remark},
            };
          }
          if (method == 'K260913000612') {
            profiles++;
            return {'nickname': 'Original nickname'};
          }
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DirectChatPage(
            peerAccount: 'peer',
            peerName: 'Old entry name',
            repository: repo,
            chatOutbox: MemoryOutbox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LegacyMessagingHeader>(find.byType(LegacyMessagingHeader))
            .title,
        'New remark',
      );
      expect(profiles, 1);
      await tester.tap(find.byKey(const ValueKey('direct-chat-details')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DirectChatDetailsPage>(find.byType(DirectChatDetailsPage))
            .peerName,
        'New remark',
      );
      remark = '';
      Navigator.of(tester.element(find.byType(DirectChatDetailsPage))).pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LegacyMessagingHeader>(find.byType(LegacyMessagingHeader))
            .title,
        'Original nickname',
      );
      expect(find.text('Old entry name'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
