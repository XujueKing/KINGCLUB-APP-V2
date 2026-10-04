import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/together_store.dart';
import 'package:kingclub/src/features/club/presentation/together_store_picker_page.dart';

class _Stores implements TogetherStoreRepository {
  _Stores(this.items);
  final List<TogetherStore> items;
  @override
  Future<List<TogetherStore>> list({required String cityCode}) async => items;
  @override
  Future<List<TogetherTable>> tables({required String storeRef}) async => [];
}

void main() {
  const eligible = TogetherStore(
    ref: 'yes',
    name: 'KING 湖南工大店',
    cityCode: '430200',
    address: '湖南工业大学旁',
    personalPartyEnabled: true,
  );
  testWidgets('whole page lists eligible stores and returns selected store', (
    tester,
  ) async {
    TogetherStore? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await TogetherStorePickerPage.open(
                  context,
                  repository: _Stores([
                    eligible,
                    const TogetherStore(
                      ref: 'no',
                      name: '未开通店',
                      cityCode: '430200',
                      address: '',
                    ),
                    const TogetherStore(
                      ref: 'other',
                      name: '外地店',
                      cityCode: 'other',
                      address: '',
                      personalPartyEnabled: true,
                    ),
                  ]),
                  cityCode: '430200',
                  cityName: '株洲市',
                );
              },
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(find.text('选择商家'), findsOneWidget);
    expect(find.text('湖南工业大学旁'), findsOneWidget);
    expect(find.text('暂无评分'), findsOneWidget);
    expect(find.text('未开通店'), findsNothing);
    expect(find.text('外地店'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('together-store-yes')));
    await tester.pumpAndSettle();
    expect(selected, same(eligible));
  });
  testWidgets('empty eligibility has no selectable fallback store', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TogetherStorePickerPage(
          repository: _Stores([]),
          cityCode: '430200',
          cityName: '株洲市',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('当前城市暂无可发起组局的商家'), findsOneWidget);
  });
}
