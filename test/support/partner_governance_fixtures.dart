import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> termsSnapshot() => {
  'hash': 'a' * 64,
  'document': {
    'version': '2026-10-07-v1',
    'title': {
      for (final l in ['zh-CN', 'en', 'zh-TW', 'th']) l: 'KINGCLUB合作者条款和规则',
    },
    'intro': {
      for (final l in ['zh-CN', 'en', 'zh-TW', 'th'])
        l: 'Synthetic version for testing',
    },
    'sections': [
      {
        'important': true,
        'title': {
          for (final l in ['zh-CN', 'en', 'zh-TW', 'th']) l: '合作规则',
        },
        'body': {
          for (final l in ['zh-CN', 'en', 'zh-TW', 'th'])
            l: 'Synthetic terms. Read and explicitly agree before applying.',
        },
      },
    ],
  },
  'accepted': null,
};

Future<void> readAndAgree(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('partner-terms-link')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('partner-terms-link')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('partner-terms-read')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('partner-terms-read')));
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('partner-terms-checkbox')),
  );
  await tester.tap(find.byKey(const ValueKey('partner-terms-checkbox')));
  await tester.pumpAndSettle();
}
