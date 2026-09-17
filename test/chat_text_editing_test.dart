import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/presentation/chat_text_editing.dart';

void main() {
  test('backspace follows cursor and preserves following text', () {
    final result = deleteChatTextBackward(
      const TextEditingValue(
        text: 'abcd',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(result.text, 'acd');
    expect(result.selection.baseOffset, 1);
  });
  test('selection is deleted and composing state is cleared', () {
    final result = deleteChatTextBackward(
      const TextEditingValue(
        text: 'abcd',
        selection: TextSelection(baseOffset: 3, extentOffset: 1),
        composing: TextRange(start: 1, end: 3),
      ),
    );
    expect(result.text, 'ad');
    expect(result.composing, TextRange.empty);
  });
  test('joined emoji is removed as one character', () {
    const emoji = '\u{1f469}\u{200d}\u{1f4bb}';
    final result = deleteChatTextBackward(
      TextEditingValue(
        text: 'a${emoji}b',
        selection: TextSelection.collapsed(offset: 1 + emoji.length),
      ),
    );
    expect(result.text, 'ab');
    expect(result.selection.baseOffset, 1);
  });
  test('cursor at start does not delete the last character', () {
    const value = TextEditingValue(
      text: 'abc',
      selection: TextSelection.collapsed(offset: 0),
    );
    expect(deleteChatTextBackward(value), value);
  });
}
