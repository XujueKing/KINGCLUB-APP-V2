import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/scanner/data/scan_route.dart';

void main() {
  test('实际 V1 印刷码进入点单而不是无效码', () {
    final route = ScanRoute.parse(
      'https://www.wuyexin.cn/view/static/kingclubaddfriend/?type=9&tableld=K24000000001&shopld=0&tableName=V1',
    );
    expect(route.kind, ScanRouteKind.tableOrdering);
    expect(route.location, '/commerce/ordering?tableId=K24000000001');
  });
  test('换域名与路径仍按 type=9 和 tableId 路由', () {
    for (final prefix in [
      'https://old.example/card',
      'https://new.example/order',
    ]) {
      final route = ScanRoute.parse('$prefix?tableId=T%26A&type=9');
      expect(route.kind, ScanRouteKind.tableOrdering);
      expect(Uri.parse(route.location!).queryParameters, {'tableId': 'T&A'});
    }
  });
  test('好友群码继续走新版协议', () {
    final token = 'A' * 32;
    expect(ScanRoute.parse('KC:M:$token').kind, ScanRouteKind.member);
    expect(ScanRoute.parse('KC:G:$token').kind, ScanRouteKind.group);
    expect(
      ScanRoute.parse('kingclub://member/v1/a.b.c').kind,
      ScanRouteKind.member,
    );
  });
  test('未接通旧类型、非法桌卡和普通网址不流入好友解析', () {
    for (final raw in [
      'https://example.test?type=1&code=ticket',
      'https://example.test?type=3&code=wine',
      'https://example.test?type=7&code=coupon',
      'type=0&code=friend',
      'type=9&tableName=V1',
      'type=9&tableId=A&tableId=B',
      'https://example.test',
    ]) {
      expect(ScanRoute.parse(raw).kind, ScanRouteKind.unsupported, reason: raw);
    }
  });
}
