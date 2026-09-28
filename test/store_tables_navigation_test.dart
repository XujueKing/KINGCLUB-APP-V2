import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kingclub/src/navigation/app_router.dart';
import 'package:kingclub/src/features/commerce/presentation/managed_tables_page.dart';
import 'package:kingclub/src/features/commerce/data/commerce_endpoint.dart';

void main() {
  testWidgets(
    'Store tables respects its gate and opens below the page navigator',
    (tester) async {
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
      if (!const bool.fromEnvironment('KINGCLUB_TABLE_MANAGEMENT_ENABLED') ||
          kingclubCommerceApiBaseUrl.isEmpty) {
        expect(entry, findsNothing);
        return;
      }
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ManagedTablesPage), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ManagedTablesPage), findsNothing);
    },
  );
}
