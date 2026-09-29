import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/legacy_messaging_components.dart';

void main() {
  test('only emoji messages enlarge, including joined and modified emoji', () {
    for (final value in ['😀', '❤️ 👍🏽', '👨‍👩‍👧‍👦', '🇨🇳', '1️⃣']) {
      expect(chatEmojiOnly(value), isTrue, reason: value);
    }
    for (final value in ['', ' ', '123', '你好😀', 'hello', '\u200D']) {
      expect(chatEmojiOnly(value), isFalse, reason: value);
    }
  });
}
