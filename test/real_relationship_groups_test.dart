import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/data/contact_groups_repository.dart';
import 'package:kingclub/src/features/contacts/presentation/relationship_groups_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets(
    'failed group save keeps editor and retry publishes acknowledged icons',
    (tester) async {
      var saves = 0;
      final ids = <String>[];
      List<ContactGroup> published = [];
      final repo = ContactGroupsRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000615') return {'version': 0, 'groups': []};
            saves++;
            ids.add(params['requestId'] as String);
            if (saves == 1) throw StateError('Synthetic network failure');
            return {'version': 1, 'groups': params['groups']};
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RelationshipGroupsPage(
            contacts: const {'peer': 'Friend'},
            groups: const [],
            repository: repo,
            onChanged: (groups) => published = groups,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('新建分组'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '同学');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '同学',
      );
      expect(published, isEmpty);
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(published.single.name, '同学');
      expect(ids[0], ids[1]);
      expect(tester.takeException(), isNull);
    },
  );
}
