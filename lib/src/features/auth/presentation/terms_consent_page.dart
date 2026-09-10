import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_theme.dart';

enum AgreementKind { terms, privacy }

class TermsConsentPage extends StatefulWidget {
  const TermsConsentPage({
    super.key,
    required this.initialAgreement,
    required this.onClose,
  });

  final AgreementKind initialAgreement;
  final VoidCallback onClose;

  @override
  State<TermsConsentPage> createState() => _TermsConsentPageState();
}

class _TermsConsentPageState extends State<TermsConsentPage> {
  late final Future<_LegacyAgreementCatalog> _catalog =
      _loadLegacyAgreementCatalog();

  @override
  Widget build(BuildContext context) {
    final isTerms = widget.initialAgreement == AgreementKind.terms;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: KingColors.textPrimary,
          leading: IconButton(
            key: const ValueKey('agreement-back'),
            onPressed: widget.onClose,
            tooltip: '返回',
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          ),
          title: Text(isTerms ? 'KINGBAR用户协议' : 'KINGBAR隐私政策'),
          centerTitle: true,
        ),
        body: SafeArea(
          child: FutureBuilder<_LegacyAgreementCatalog>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('协议正文暂时无法显示'));
              }
              final catalog = snapshot.data;
              if (catalog == null) {
                return const Center(
                  child: CircularProgressIndicator(color: KingColors.brand),
                );
              }
              final paragraphs = isTerms ? catalog.terms : catalog.privacy;
              return SelectionArea(
                child: ListView.builder(
                  key: ValueKey(
                    isTerms ? 'legacy-user-agreement' : 'legacy-privacy-policy',
                  ),
                  padding: const EdgeInsets.fromLTRB(25, 0, 25, 50),
                  itemCount: paragraphs.length,
                  itemBuilder: (context, index) =>
                      _LegacyAgreementParagraphView(paragraphs[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LegacyAgreementParagraphView extends StatelessWidget {
  const _LegacyAgreementParagraphView(this.paragraph);

  final _LegacyAgreementParagraph paragraph;

  @override
  Widget build(BuildContext context) {
    final text = paragraph.type == 3 ? '《${paragraph.text}》' : paragraph.text;
    if (text.isEmpty) return const SizedBox(height: 10);

    final (style, padding, alignment) = switch (paragraph.type) {
      3 => (
        const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          height: 1.45,
        ),
        const EdgeInsets.fromLTRB(0, 30, 0, 20),
        TextAlign.center,
      ),
      1 => (
        const TextStyle(color: Colors.white, fontSize: 17.5, height: 1.5),
        const EdgeInsets.fromLTRB(0, 22.5, 0, 10),
        TextAlign.start,
      ),
      8 => (
        const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.55,
        ),
        const EdgeInsets.symmetric(vertical: 10),
        TextAlign.start,
      ),
      _ => (
        const TextStyle(
          color: Color(0xFFCCCCCC),
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.55,
        ),
        const EdgeInsets.symmetric(vertical: 10),
        TextAlign.start,
      ),
    };

    return Padding(
      padding: padding,
      child: Text(text, style: style, textAlign: alignment),
    );
  }
}

class _LegacyAgreementCatalog {
  const _LegacyAgreementCatalog({required this.terms, required this.privacy});

  final List<_LegacyAgreementParagraph> terms;
  final List<_LegacyAgreementParagraph> privacy;
}

class _LegacyAgreementParagraph {
  const _LegacyAgreementParagraph({required this.type, required this.text});

  factory _LegacyAgreementParagraph.fromJson(Map<String, dynamic> json) =>
      _LegacyAgreementParagraph(
        type: json['a'] as int? ?? 0,
        text: json['b'] as String? ?? '',
      );

  final int type;
  final String text;
}

Future<_LegacyAgreementCatalog> _loadLegacyAgreementCatalog() async {
  final source = await rootBundle.loadString(
    'assets/legacy/legal/agreements.json',
  );
  final json = jsonDecode(source) as Map<String, dynamic>;
  List<_LegacyAgreementParagraph> decode(String key) =>
      (json[key] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_LegacyAgreementParagraph.fromJson)
          .toList(growable: false);
  return _LegacyAgreementCatalog(
    terms: decode('terms'),
    privacy: decode('privacy'),
  );
}
