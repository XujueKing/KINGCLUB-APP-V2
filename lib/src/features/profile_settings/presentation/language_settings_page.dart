import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_language.dart';
import '../../../core/design_system/king_localizations.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key, this.language});
  final KingLanguage? language;

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  bool _saving = false;
  KingLanguage get _language => widget.language ?? KingLanguage.shared;
  String _text(List<String> values) =>
      kingText(Localizations.localeOf(context), values);

  Future<void> _select(Locale locale) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _language.select(locale);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _text([
              '语言保存失败，请重试',
              'Could not save language. Please try again.',
              '語言儲存失敗，請重試',
              'บันทึกภาษาไม่สำเร็จ กรุณาลองอีกครั้ง',
            ]),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = kingLanguageIndex(
      _language.value ?? Localizations.localeOf(context),
    );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: kingAppBar(
        context: context,
        centerTitle: true,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: KingBackButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          tooltip: _text(['返回', 'Back', '返回', 'ย้อนกลับ']),
        ),
        title: Text(
          _text(['语言', 'Language', '語言', 'ภาษา']),
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          itemCount: kingSupportedLocales.length,
          separatorBuilder: (_, _) =>
              const Divider(color: Color(0xFF282828), height: 1),
          itemBuilder: (_, index) => ListTile(
            key: ValueKey(
              'language-${kingSupportedLocales[index].toLanguageTag()}',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            title: Text(
              kingLanguageNames[index],
              style: const TextStyle(color: Colors.white, fontSize: 17),
            ),
            selected: selected == index,
            trailing: selected == index
                ? const Icon(Icons.check, color: Color(0xFFC9B69E))
                : null,
            enabled: !_saving,
            onTap: () => _select(kingSupportedLocales[index]),
          ),
        ),
      ),
    );
  }
}
