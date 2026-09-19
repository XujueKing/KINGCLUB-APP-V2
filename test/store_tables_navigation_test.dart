import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kingclub/src/navigation/app_router.dart';
import 'package:kingclub/src/features/commerce/presentation/managed_tables_page.dart';

void main() {
  testWidgets('Store tables uses a context below the page navigator', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const SettingsRoute().buildPage(context, state),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final entry = find.text('Store tables');
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ManagedTablesPage), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ManagedTablesPage), findsNothing);
  });
}
