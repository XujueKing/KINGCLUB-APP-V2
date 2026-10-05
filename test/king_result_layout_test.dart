import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_result_page.dart';

void main() {
  testWidgets(
    'result content and return button center on the full phone width',
    (tester) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: KingResultPage(
            title: '扣款成功',
            description: '门店\n0.10',
            buttonText: '查看余额',
            onReturn: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final finder in [
        find.text('扣款成功'),
        find.byType(KingResultIcon),
        find.byType(FilledButton),
      ]) {
        expect(tester.getCenter(finder).dx, closeTo(201, .1));
      }
      expect(tester.getRect(find.byType(FilledButton)).left, greaterThan(20));
      expect(tester.takeException(), isNull);
    },
  );
}
