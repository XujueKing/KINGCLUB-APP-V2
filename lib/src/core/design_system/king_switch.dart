import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Uses the chat-details switch appearance on every platform.
class KingSwitch extends CupertinoSwitch {
  const KingSwitch({super.key, required super.value, required super.onChanged})
    : super(
        activeTrackColor: const Color(0xFF07C160),
        inactiveTrackColor: const Color(0xFF39393D),
        thumbColor: Colors.white,
        inactiveThumbColor: Colors.white,
        applyTheme: false,
      );
}

class KingSwitchListTile extends StatelessWidget {
  const KingSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.contentPadding,
    required this.value,
    required this.onChanged,
  });

  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      contentPadding: contentPadding,
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      trailing: KingSwitch(value: value, onChanged: onChanged),
      onTap: onChanged == null ? null : () => onChanged!(!value),
    ),
  );
}
