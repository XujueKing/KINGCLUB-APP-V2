import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/friend_radar_view.dart';

void main() {
  testWidgets(
    'radar animates without moving avatars and opens discovered person',
    (tester) async {
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: FriendRadarView(
            selfAvatar: const CircleAvatar(key: ValueKey('self')),
            people: [
              (
                account: 'friend',
                avatar: const CircleAvatar(key: ValueKey('peer')),
                onTap: () => opened = true,
              ),
            ],
            active: true,
            busy: false,
            onToggle: () {},
            onBack: () {},
          ),
        ),
      );
      expect(find.byType(AppBar), findsNothing);
      final self = tester.getCenter(find.byKey(const ValueKey('self')));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getCenter(find.byKey(const ValueKey('self'))), self);
      await tester.tap(find.byKey(const ValueKey('peer')));
      expect(opened, isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
