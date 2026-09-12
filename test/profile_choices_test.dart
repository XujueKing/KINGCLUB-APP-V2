import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/profile_choices.dart';
void main() {
  testWidgets('measurement has half kilogram ticks and returns selected value', (tester) async {
    double? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () async { result = await selectProfileMeasure(context,title:'体重',unit:'kg',min:30,max:250,step:.5,initial:62.5); },child:const Text('open'))))));
    await tester.tap(find.text('open')); await tester.pumpAndSettle();
    final slider=tester.widget<Slider>(find.byType(Slider));
    expect(slider.divisions,440); expect(slider.value,62.5);
    await tester.tap(find.byIcon(Icons.add)); await tester.pump();
    expect(find.text('63.0 kg'),findsOneWidget);
    await tester.tap(find.text('确定')); await tester.pumpAndSettle();
    expect(result,63);
  });
  testWidgets('offline city search narrows province and city names', (tester) async {
    await tester.pumpWidget(const MaterialApp(home:ProfileCityPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField),'株洲'); await tester.pumpAndSettle();
    expect(find.text('湖南省 · 株洲市'),findsOneWidget);
    expect(find.text('北京市 · 北京市'),findsNothing);
  });
}
