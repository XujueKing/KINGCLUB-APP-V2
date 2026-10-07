import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

String partnerLanguage(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'en') return 'en';
  if (locale.languageCode == 'th') return 'th';
  return locale.scriptCode == 'Hant' ||
          ['TW', 'HK', 'MO'].contains(locale.countryCode)
      ? 'zh-TW'
      : 'zh-CN';
}

class PartnerTermsPage extends StatefulWidget {
  const PartnerTermsPage({
    super.key,
    required this.call,
    this.forApplication = false,
    this.version,
  });
  final PartnerCall call;
  final bool forApplication;
  final String? version;
  @override
  State<PartnerTermsPage> createState() => _TermsState();
}

class _TermsState extends State<PartnerTermsPage> {
  Map<String, dynamic>? data;
  bool busy = false, failed = false, invalid = false;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) setState(() => invalid = true);
    });
    load();
  }

  @override
  void dispose() {
    session?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (busy || invalid) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await widget.call({
        'action': 'terms',
        if (widget.version != null) 'termsVersion': widget.version,
      });
      final document = result['document'] as Map;
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}-v[1-9]\d*$')
              .hasMatch(document['version'] as String) ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(result['hash'] as String) ||
          (document['sections'] as List).isEmpty) {
        throw const FormatException('Incomplete terms');
      }
      if (mounted && !invalid) setState(() => data = result);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = data?['document'] as Map?;
    final language = partnerLanguage(context);
    String copy(dynamic value) => (value as Map)[language] as String;
    final accepted = data?['accepted'] as Map?;
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: Text(t('terms')),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (invalid)
              Text(t('actionFailed'))
            else if (busy && data == null)
              const Center(child: CircularProgressIndicator())
            else if (failed) ...[
              Text(t('failed')),
              TextButton(onPressed: load, child: Text(t('retry'))),
            ] else if (document != null) ...[
              Text(
                copy(document['title']),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                copy(document['intro']),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              if (accepted != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${t('acceptedVersion')} ${accepted['version']}\n${accepted['date']}',
                  style: const TextStyle(color: Color(0xffcebea4), height: 1.5),
                ),
                if (accepted['version'] != document['version'])
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => PartnerTermsPage(
                          call: widget.call,
                          version: accepted['version'] as String,
                        ),
                      ),
                    ),
                    child: Text(t('viewAcceptedTerms')),
                  ),
              ],
              const SizedBox(height: 20),
              for (final section in document['sections'] as List)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: section['important'] == true
                        ? const Color(0xff2b2822)
                        : const Color(0xff202020),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        copy(section['title']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        copy(section['body']),
                        style: const TextStyle(
                          color: Color(0xffdddddd),
                          fontSize: 16,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.forApplication)
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const ValueKey('partner-terms-read'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xffcebea4),
                      foregroundColor: Colors.black,
                      shape: const StadiumBorder(),
                    ),
                    onPressed: () => Navigator.pop(context, <String, dynamic>{
                      'termsVersion': document['version'],
                      'termsHash': data!['hash'],
                      'termsLanguage': language,
                    }),
                    child: Text(t('readTerms')),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
