import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/data/profile_repository.dart';
import 'package:kingclub/src/features/profile_settings/presentation/favourite_store_page.dart';

class Repository extends ProfileRepository {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> store(String ref) async {
    calls++;
    return {
      'store': {
        'storeRef': ref,
        'storeName': 'A very long store name 湖南工大店',
        'storeAddress': 'A long address for narrow screens',
        'currency': 'CNY',
        'personalPartyEnabled': 0,
      },
      'packages': [
        {
          'namesJson': {'en': 'Party package'},
          'specificationsJson': {'en': 'Package details'},
          'priceCents': '123400',
        },
      ],
      'tables': [
        {'tableRef': 't', 'tableName': 'V1', 'maximumSeats': 6},
      ],
    };
  }
}

void main() {
  testWidgets(
    'store landing loads once and shows authoritative packages and tables',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = Repository();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: FavouriteStorePage(
            store: const {'storeRef': 's'},
            repository: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('CNY 1,234.00'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('V1 · 6 guests'), 150);
      expect(find.text('V1 · 6 guests'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
