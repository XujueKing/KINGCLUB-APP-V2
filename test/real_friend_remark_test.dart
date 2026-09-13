import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/friend_remark_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets(
    'failed save retains remark and retries the real settings request',
    (tester) async {
      var calls = 0;
      FriendRemarkResult? saved;
      final repo = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          expect(id, 'K260913000606');
          expect(params, {'peer': 'peer', 'remark': 'New remark'});
          calls++;
          if (calls == 1) throw StateError('offline');
          return {'saved': true};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRemarkPage(
            targetRef: 'peer',
            initialRemark: '',
            signature: '',
            repository: repo,
            onSaved: (v) => saved = v,
            onBack: () {},
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('friend-remark-name')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New remark');
      await tester.tap(find.byKey(const ValueKey('friend-remark-confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('New remark'), findsOneWidget);
      expect(find.text('2026-08-25'), findsNothing);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(saved?.remark, 'New remark');
      expect(calls, 2);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
