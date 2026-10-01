import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/group_chat_avatar.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';

void main() {
  test('group portraits cover the entire image without gaps or overlap', () {
    expect(groupAvatarTiles(2), [
      const Rect.fromLTWH(0, 0, 72, 144),
      const Rect.fromLTWH(72, 0, 72, 144),
    ]);
    expect(groupAvatarTiles(3), [
      const Rect.fromLTWH(0, 0, 144, 72),
      const Rect.fromLTWH(0, 72, 72, 72),
      const Rect.fromLTWH(72, 72, 72, 72),
    ]);
    for (var count = 1; count <= 9; count++) {
      final tiles = groupAvatarTiles(count);
      expect(tiles.length, count);
      expect(
        tiles.fold<double>(0, (sum, r) => sum + r.width * r.height),
        closeTo(144 * 144, .001),
      );
      for (var i = 0; i < tiles.length; i++) {
        expect(
          (const Rect.fromLTWH(0, 0, 144, 144)).intersect(tiles[i]),
          tiles[i],
        );
        for (var j = i + 1; j < tiles.length; j++) {
          expect(tiles[i].overlaps(tiles[j]), isFalse);
        }
      }
    }
  });

  testWidgets('chat and contacts badges update independently on either tab', (
    tester,
  ) async {
    for (final selected in [true, false]) {
      Rect? chatRect;
      Rect? contactsRect;
      for (final counts in [(3, 2), (0, 2), (3, 0), (0, 0)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: LegacyConversationTabs(
                chatSelected: selected,
                unreadCount: counts.$1,
                pendingRequests: counts.$2,
                onChat: () {},
                onContacts: () {},
                onAdd: () {},
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<Badge>(
                find.byKey(const ValueKey('chat-tab-unread-badge')),
              )
              .isLabelVisible,
          counts.$1 > 0,
        );
        expect(
          tester
              .widget<Badge>(
                find.byKey(const ValueKey('contacts-tab-request-badge')),
              )
              .isLabelVisible,
          counts.$2 > 0,
        );
        expect(tester.takeException(), isNull);
        for (final badge in tester.widgetList<Badge>(find.byType(Badge))) {
          expect(badge.label, isNull);
          expect(badge.smallSize, 6);
        }
        final chatNow = tester.getRect(find.text('聊天'));
        final contactsNow = tester.getRect(find.text('通讯录'));
        expect(chatNow.bottom, closeTo(contactsNow.bottom, .01));
        chatRect ??= chatNow;
        contactsRect ??= contactsNow;
        expect(chatNow, chatRect);
        expect(contactsNow, contactsRect);
      }
    }
  });
}
