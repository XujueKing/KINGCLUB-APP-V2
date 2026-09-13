import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/data/contact_groups_repository.dart';
import 'package:kingclub/src/features/contacts/presentation/relationship_groups_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  testWidgets(
    'cleanup checks real contacts and only removes unavailable group members',
    (tester) async {
      final original = ContactGroup('id', '好友', 2, {'keep', 'gone'});
      var published = [original];
      var saves = 0;
      final repo = ContactGroupsRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000615')
              return {
                'version': 1,
                'groups': [original.toJson()],
              };
            if (id == 'K260913000608')
              return {
                'items': [
                  {'peer': 'keep'},
                ],
                'hasMore': false,
              };
            expect(id, 'K260913000616');
            saves++;
            expect((params['groups'] as List).single['members'], ['keep']);
            return {'version': 2, 'groups': params['groups']};
          },
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: RelationshipGroupsPage(
            contacts: const {},
            groups: const [],
            repository: repo,
            onChanged: (groups) => published = groups,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('清理失效成员'));
      await tester.pumpAndSettle();
      expect(saves, 0);
      expect(published.single.members, {'keep', 'gone'});
      await tester.tap(find.text('确认清理'));
      await tester.pumpAndSettle();
      expect(published.single.id, 'id');
      expect(published.single.members, {'keep'});
      expect(saves, 1);
    },
  );

  testWidgets(
    'deleting a group needs acknowledgement and does not change friendships',
    (tester) async {
      final group = ContactGroup('id', '同学', 1, {'peer'});
      var attempts = 0;
      final requests = <Map<String, dynamic>>[];
      var published = [group];
      final repo = ContactGroupsRepository(
        MessagingRepository(
          account: 'me',
          call: (id, params) async {
            if (id == 'K260913000615')
              return {
                'version': 1,
                'groups': [group.toJson()],
              };
            expect(id, 'K260913000616');
            expect(params['groups'], isEmpty);
            requests.add(params);
            attempts++;
            if (attempts == 1) throw StateError('Synthetic failure');
            return {'version': 2, 'groups': []};
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
      await tester.tap(find.text('同学'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除分组'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(attempts, 0);
      await tester.tap(find.text('删除分组'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(published.single.id, 'id');
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('删除分组'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(published, isEmpty);
      expect(find.byType(TextField), findsNothing);
      expect(requests[0]['requestId'], requests[1]['requestId']);
    },
  );

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
