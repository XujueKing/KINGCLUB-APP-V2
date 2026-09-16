import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_theme.dart';

void main() {
  testWidgets('conversation route slides horizontally at unchanged size', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    const pageKey = ValueKey('conversation-surface');
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('list')),
      ),
    );
    navigator.currentState!.push(
      KingPageRoute<void>(
        builder: (_) =>
            const Scaffold(key: pageKey, body: Text('conversation')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final during = tester.getRect(find.byKey(pageKey));
    expect(during.left, greaterThan(0));
    expect(during.left, lessThan(800));
    expect(during.top, 0);
    expect(during.size, const Size(800, 600));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(pageKey)), Offset.zero);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.byKey(pageKey)).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
  });
}
