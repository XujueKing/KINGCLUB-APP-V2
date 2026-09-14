import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kingclub/src/features/messaging/data/group_chat_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/presentation/group_details_page.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_member_avatar.dart';

void main() {
  for (final owner in [true, false]) {
    testWidgets(
      'member management role boundary and confirmed removal owner=$owner',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        var removed = false;
        final profileAccounts = <String>[];
        Map<String, dynamic>? request;
        final repo = GroupChatRepository(
          MessagingRepository(
            account: 'me',
            call: (id, params) async {
              if (id == 'K260913000619') {
                return {
                  'groupName': '管理测试',
                  'ownerAccount': owner ? 'me' : 'leader',
                  'metadataVersion': 8,
                  'membershipVersion': 0,
                  'members': [
                    {
                      'account': 'me',
                      'nickname': '本人',
                      'role': owner ? 'owner' : 'admin',
                      'membershipVersion': 0,
                    },
                    if (!owner)
                      {
                        'account': 'leader',
                        'nickname': '群主本人',
                        'role': 'owner',
                        'membershipVersion': 0,
                      },
                    {
                      'account': 'admin',
                      'nickname': '另一管理员',
                      'role': 'admin',
                      'membershipVersion': 2,
                    },
                    if (!removed)
                      {
                        'account': 'member',
                        'nickname': '普通成员',
                        'role': 'member',
                        'membershipVersion': 3,
                      },
                  ],
                };
              }
              if (id == 'K260912000501' || id == 'K260913000612') {
                profileAccounts.add(
                  id == 'K260912000501' ? 'me' : params['peer'] as String,
                );
                return {'avatar': null};
              }
              if (id == 'K260913000621') return {'settings': {}};
              if (id == 'K260913000627') {
                request = params;
                removed = true;
                return {'changed': true};
              }
              throw StateError(id);
            },
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: GroupDetailsPage(groupId: 'group', repository: repo),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('group-member-actions-member')),
          150,
        );
        await tester.pumpAndSettle();
        expect(profileAccounts, containsAll(['me', 'admin', 'member']));
        expect(profileAccounts.toSet().length, profileAccounts.length);
        expect(find.byType(ChatMemberAvatar), findsNWidgets(owner ? 3 : 4));
        expect(
          find.byKey(const ValueKey('group-member-actions-me')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('group-member-actions-leader')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('group-member-actions-admin')),
          owner ? findsOneWidget : findsNothing,
        );
        final button = find.byKey(
          const ValueKey('group-member-actions-member'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.text('设为管理员'), owner ? findsOneWidget : findsNothing);
        await tester.tap(find.text('移出群聊'));
        await tester.pumpAndSettle();
        expect(request, isNull);
        await tester.tap(find.byKey(const ValueKey('group-member-confirm')));
        await tester.pumpAndSettle();
        expect(request, {
          'groupId': 'group',
          'target': 'member',
          'action': 'remove',
          'expectedVersion': 8,
          'membershipVersion': 3,
        });
        expect(find.text('普通成员'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
