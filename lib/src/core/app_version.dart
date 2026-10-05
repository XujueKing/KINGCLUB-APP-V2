import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reads the installed package, including CI build-number overrides.
class InstalledAppVersion extends StatefulWidget {
  const InstalledAppVersion({super.key, this.style});
  final TextStyle? style;
  @override
  State<InstalledAppVersion> createState() => _InstalledAppVersionState();
}

class _InstalledAppVersionState extends State<InstalledAppVersion> {
  late final Future<String?> version = _read();
  Future<String?> _read() async {
    try {
      final value = await const MethodChannel('kingclub/app-version')
          .invokeMapMethod<String, String>('read');
      final name = value?['version'], build = value?['build'];
      if (name == null || name.isEmpty || build == null || build.isEmpty) {
        return null;
      }
      return '$name ($build)';
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: version,
    builder: (_, snapshot) => Text(
      snapshot.data ?? '—',
      key: const ValueKey('installed-app-version'),
      style: widget.style,
    ),
  );
}
