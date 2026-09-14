import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_file_card.dart';

void main() {
  testWidgets('file card shows metadata and supports bounded long names', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: ChatFileCard(fileName: '测试文件名' * 30, size: 1536),
          ),
        ),
      ),
    );
    expect(find.text('1.5 KB'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(ChatFileCard.formatSize(0), '0 B');
    expect(ChatFileCard.formatSize(268435456), '256.0 MB');
  });
}
