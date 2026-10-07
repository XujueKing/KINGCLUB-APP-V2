import 'package:flutter/widgets.dart';

/// Mobile forms dismiss the keyboard when tapping outside the active input.
/// TextFieldTapRegion still keeps input accessories in the same tap region.
class KingKeyboardDismiss extends StatelessWidget {
  const KingKeyboardDismiss({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      EditableTextTapOutsideIntent:
          CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
    },
    child: child,
  );
}
