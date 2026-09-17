import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/commerce/data/table_ordering_code.dart';

void main() {
  test('旧 type=9 码保留桌台与旧店铺定位', () {
    final code = TableOrderingCode.tryParse(
      'https://example.test/card/?type=9&tableId=T1&shopId=S1&tableName=V1',
    )!;
    expect(code.tableId, 'T1');
    expect(code.legacyShopId, 'S1');
    expect(code.tableName, 'V1');
    expect(code.barId, isNull);
    expect(code.cityId, isNull);
  });
  test('缺酒吧城市旧码仍可解析，交由档案补关联', () {
    expect(TableOrderingCode.tryParse('type=9&tableId=T1')?.tableId, 'T1');
  });
  test('新字段和参数顺序不影响识别', () {
    final code = TableOrderingCode.tryParse(
      'type=9&cityId=C1&tableName=V1&barId=B1&tableId=T1',
    )!;
    expect(code.barId, 'B1');
    expect(code.cityId, 'C1');
  });
  test('兼容整体编码及字段编码，不把编码的分隔符拆成新字段', () {
    const link =
        'https://example.test/card?type=9&tableId=T1&tableName=VIP%26A';
    expect(
      TableOrderingCode.tryParse(Uri.encodeComponent(link))?.tableName,
      'VIP&A',
    );
    expect(TableOrderingCode.tryParse(link)?.tableName, 'VIP&A');
  });
  test('其他业务码和只有桌名不能冒充桌台唯一记录', () {
    for (final raw in [
      'V1',
      'type=9&tableName=V1',
      'type=3&tableId=T1',
      'KC:G:demo',
    ]) {
      expect(TableOrderingCode.tryParse(raw), isNull);
    }
  });
  test('重复关键字段和非法输入拒绝', () {
    for (final raw in [
      'type=9&tableId=A&tableId=B',
      'type=9&type=3&tableId=A',
      'type=9&tableId=',
      'type=9&tableId=%ZZ',
      'type=9&tableId=%00',
      'javascript:alert?type=9&tableId=A',
      'https://example.test/?type=9&tableId=A#x',
      'type=9&tableId=A&cityId=C&cityId=D',
    ]) {
      expect(TableOrderingCode.tryParse(raw), isNull, reason: raw);
    }
  });
}
