import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/design_system/king_text_scale.dart';

void main() {
  testWidgets('A keeps its text size and B text/input share compact scaling', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final sample in [(360.0, 800.0, 1.0), (320.0, 712.9, 1.35)]) {
      tester.view.physicalSize = Size(sample.$1, sample.$2);
      await tester.binding.setSurfaceSize(Size(sample.$1, sample.$2));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(sample.$3)),
            child: KingTextScale(child: child!),
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('聊天', style: TextStyle(fontSize: 26)),
                      SizedBox(width: 16),
                      Text('通讯录', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                  TextField(decoration: InputDecoration(hintText: '搜索')),
                ],
              ),
            ),
          ),
        ),
      );
      final titleScale =
          MediaQuery.textScalerOf(tester.element(find.text('聊天'))).scale(26) /
          26;
      final inputScale =
          MediaQuery.textScalerOf(tester.element(find.byType(EditableText)))
              .scale(16) /
          16;
      expect(titleScale, closeTo(sample.$1 == 360 ? 1 : 0.99, 0.001));
      expect(inputScale, closeTo(titleScale, 0.001));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
