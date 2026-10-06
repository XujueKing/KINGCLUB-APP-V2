import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:kingclub/src/features/partners/presentation/partner_code_page.dart';
import 'package:kingclub/src/features/scanner/data/scan_route.dart';

const code = 'KC:P:0123456789ABCDEF0123456789ABCDEF';
void main() {
  test('referral codes have a distinct strict route', () {
    expect(ScanRoute.parse(code).kind, ScanRouteKind.partner);
    expect(ScanRoute.parse('$code\n').kind, ScanRouteKind.unsupported);
    expect(ScanRoute.parse(code.toLowerCase()).kind, ScanRouteKind.unsupported);
  });
  testWidgets('expired code is removed from display', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PartnerCodePage(
          call: (_) async => {'code': code, 'ttlSeconds': 600},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    await tester.pump(const Duration(minutes: 10));
    expect(find.byType(QrImageView), findsNothing);
  });
  testWidgets('preview requires confirmation and guards double submission', (
    tester,
  ) async {
    final requests = <String>[];
    final binding = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      MaterialApp(
        home: PartnerCodePage(
          code: code,
          call: (p) async {
            requests.add(p['action'] as String);
            return p['action'] == 'bind'
                ? binding.future
                : {'name': 'Partner', 'bound': false};
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, ['preview']);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    expect(requests, ['preview', 'bind']);
    binding.complete({'name': 'Partner', 'bound': true});
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
