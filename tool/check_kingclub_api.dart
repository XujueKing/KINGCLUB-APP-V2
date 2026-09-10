import 'dart:io';

import 'package:kingclub/src/core/networking/kingclub_secure_client.dart';

Future<void> main(List<String> arguments) async {
  final baseUrl = arguments.isEmpty
      ? 'https://test.wuyexin.cn/kingclub-v2'
      : arguments.first;
  final data = await KingclubSecureClient(baseUrl).call('K260824000107', {
    'clientAppCode': 'kingclub',
    'clientType': 'android',
    'locale': 'zh-CN',
  });
  final agreements = data['agreements'] as List;
  if (agreements.length != 2) throw StateError('Expected two agreements');
  stdout.writeln('secure-api-ok agreements=${agreements.length}');
}
