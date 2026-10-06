import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/core/app_update.dart';

void main() {
  Map<String, dynamic> manifest() => {
    'schema': 1,
    'android': {
      'build': 147,
      'version': '1.0.0-preview',
      'url': 'https://test.wuyexin.cn/kingclub-updates/147.apk',
      'bytes': 209000000,
      'sha256': 'a' * 64,
      'notes': ['更新', 'Update', '更新', 'อัปเดต'],
    },
    'ios': null,
  };
  test('platforms publish independently and compare installed build', () {
    final data = manifest();
    expect(AppRelease.parse(data, 'ios'), isNull);
    final updates = AppUpdates()..installedBuild = 146;
    updates.release = AppRelease.parse(data, 'android');
    expect(updates.available, isTrue);
    updates.installedBuild = 147;
    expect(updates.available, isFalse);
    updates.installedBuild = 148;
    expect(updates.available, isFalse);
  });
  test('rejects non-HTTPS, credentials, wrong host and unexpected port', () {
    for (final url in [
      'http://test.wuyexin.cn/kingclub-updates/147.apk',
      'https://test.wuyexin.cn.attacker.invalid/kingclub-updates/147.apk',
      'https://user@test.wuyexin.cn/kingclub-updates/147.apk',
      'https://test.wuyexin.cn:8443/kingclub-updates/147.apk',
    ]) {
      final data = manifest();
      data['android']['url'] = url;
      expect(() => AppRelease.parse(data, 'android'), throwsFormatException);
    }
  });
  test('rejects corrupt and incomplete integrity metadata', () {
    for (final change in [
      {'bytes': 0},
      {'sha256': 'oops'},
      {'build': '147'},
      {
        'notes': ['one'],
      },
    ]) {
      final data = manifest();
      (data['android'] as Map).addAll(change);
      expect(() => AppRelease.parse(data, 'android'), throwsFormatException);
    }
  });
  test('iOS opens approved distribution pages only', () {
    final data = manifest();
    data['ios'] = {
      ...data['android'],
      'url': 'https://testflight.apple.com/join/example',
    };
    expect(AppRelease.parse(data, 'ios')!.build, 147);
    data['ios']['url'] = 'https://test.wuyexin.cn/test.ipa';
    expect(() => AppRelease.parse(data, 'ios'), throwsFormatException);
  });
}
