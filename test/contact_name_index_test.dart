import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/data/contact_name_index.dart';
import 'package:kingclub/src/features/contacts/presentation/contacts_page.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

void main() {
  test(
    'Chinese, traditional Chinese and Latin names have phonetic sections',
    () {
      for (final entry in {
        '徐珏': 'X',
        '张三': 'Z',
        '陳明': 'C',
        ' Alice ': 'A',
        '重庆朋友': 'C',
        '123朋友': '#',
        '😊朋友': '#',
        '': '#',
      }.entries) {
        expect(
          contactIndexSection(contactPhoneticKey(entry.key)),
          entry.value,
          reason: entry.key,
        );
      }
      final names = [
        '张伟',
        '张安',
        '赵强',
      ]..sort((a, b) => contactPhoneticKey(a).compareTo(contactPhoneticKey(b)));
      expect(names, ['张安', '张伟', '赵强']);
    },
  );

  testWidgets(
    'real contacts use visible remarks for A-Z sections and pinyin order',
    (tester) async {
      tester.view.physicalSize = const Size(393, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = MessagingRepository(
        account: 'me',
        call: (method, _) async {
          if (method == 'K260913000608') {
            return {
              'items': [
                {'peer': 'z', 'nickname': '张伟'},
                {'peer': 'x', 'nickname': '徐珏'},
                {'peer': 'c', 'nickname': '王明', 'remark': '陈朋友'},
                {'peer': 'a', 'nickname': 'Alice'},
                {'peer': 'emoji', 'nickname': '😊朋友'},
              ],
              'hasMore': false,
            };
          }
          if (method == 'K260913000611') return {'items': [], 'hasMore': false};
          if (method == 'K260913000615') return {'version': 0, 'groups': []};
          return {};
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ContactsPage(
              active: true,
              realData: true,
              repository: repo,
              onIntent: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final letter in ['A', 'C', 'X', 'Z']) {
        expect(
          find.text(letter),
          findsNWidgets(2),
        ); // Section and finger index.
      }
      expect(
        find.text('W'),
        findsOneWidget,
      ); // Nickname is superseded by remark.
      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(y('Alice'), lessThan(y('陈朋友')));
      expect(y('陈朋友'), lessThan(y('徐珏')));
      expect(y('徐珏'), lessThan(y('张伟')));
      expect(y('张伟'), lessThan(y('😊朋友')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
