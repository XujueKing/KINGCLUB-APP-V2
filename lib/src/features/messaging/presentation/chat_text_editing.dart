import 'package:flutter/widgets.dart';

/// The emoji panel backspace follows the caret and treats a composed emoji as
/// one character. Native keyboard editing remains owned by EditableText.
TextEditingValue deleteChatTextBackward(TextEditingValue value) {
  final text = value.text;
  final selection =
      value.selection.isValid && value.selection.end <= text.length
      ? value.selection
      : TextSelection.collapsed(offset: text.length);
  var start = selection.start, end = selection.end;
  if (selection.isCollapsed) {
    if (start == 0) return value;
    var offset = 0;
    for (final character in text.characters) {
      final next = offset + character.length;
      if (start <= next) {
        start = offset;
        end = next;
        break;
      }
      offset = next;
    }
  }
  return TextEditingValue(
    text: text.replaceRange(start, end, ''),
    selection: TextSelection.collapsed(offset: start),
  );
}
