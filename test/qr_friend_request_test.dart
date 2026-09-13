import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/scanner/presentation/member_scanner_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets(
    'QR request retries preserve id and note and await recipient approval',
    (tester) async {
      final calls = <Map<String, dynamic>>[];
      final repository = MessagingRepository(
        account: 'me',
        call: (id, params) async {
          expect(id, 'K260913000609');
          calls.add(Map.from(params));
          if (calls.length == 1) throw StateError('offline');
          return {'status': 'pending'};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MemberCardPreview(
            profile: const {'nickname': 'Test peer', 'isSelf': false},
            code: 'fixture-qr',
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.text('申请好友'));
      await tester.pumpAndSettle();
      expect(find.text('申请已发送，等待对方确认'), findsNothing);
      await tester.tap(find.text('重试申请'));
      await tester.pumpAndSettle();
      expect(calls.length, 2);
      expect(calls[1], calls[0]);
      expect(calls[0]['code'], 'fixture-qr');
      expect(calls[0]['note'], 'Hello');
      expect(find.text('申请已发送，等待对方确认'), findsOneWidget);
      expect(find.text('申请已通过'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('self QR has no request action', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MemberCardPreview(
          profile: {'nickname': 'Me', 'isSelf': true},
          code: 'self-qr',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('这是你的个人二维码'), findsOneWidget);
    expect(find.text('申请好友'), findsNothing);
  });
}
