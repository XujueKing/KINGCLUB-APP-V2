import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../../messaging/data/system_notices_controller.dart';
import '../../messaging/data/system_notices_repository.dart';
import '../../messaging/presentation/system_notice_copy.dart';
import '../data/partner_repository.dart';
import 'partner_notice_destination.dart';
import 'partner_strings.dart';

class PartnerMessagesPage extends StatefulWidget {
  const PartnerMessagesPage({super.key, required this.call, this.inbox});
  final PartnerCall call;
  final SystemNoticesController? inbox;
  @override
  State<PartnerMessagesPage> createState() => _MessagesState();
}

class _MessagesState extends State<PartnerMessagesPage>
    with WidgetsBindingObserver {
  final rows = <SystemNotice>[];
  StreamSubscription<Map<String, dynamic>>? events;
  StreamSubscription<void>? session;
  int page = 0, epoch = 0;
  bool busy = false, failed = false, more = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session = SecureSessionStore.changes.stream.listen((_) {
      epoch++;
      if (mounted) {
        final route = ModalRoute.of(context);
        if (route != null) Navigator.popUntil(context, (r) => r == route);
        Navigator.pop(context);
      }
    });
    events = KingclubRealtime.shared.events.listen((e) {
      if ({
        'connection.ready',
        'balance.changed',
        'system.changed',
      }.contains(e['eventType'])) {
        load(reset: true);
      }
    });
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load(reset: true);
  }

  @override
  void dispose() {
    epoch++;
    events?.cancel();
    session?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> load({bool reset = false, String? read}) async {
    if (busy) return;
    final generation = epoch;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final r = await widget.call({
        'action': read == null ? 'messages' : 'messages_read',
        'page': reset ? 0 : page,
        if (read != null) 'noticeRefs': [read],
      });
      final next = (r['items'] as List).map(SystemNotice.parse).toList();
      if (!mounted || generation != epoch) return;
      setState(() {
        if (reset) {
          rows.clear();
          page = 0;
        }
        rows.addAll(next.where((n) => !rows.any((v) => v.id == n.id)));
        page++;
        more = next.length == 30;
      });
      if (read != null) unawaited(widget.inbox?.refresh());
    } catch (_) {
      if (mounted && generation == epoch) setState(() => failed = true);
    } finally {
      if (mounted && generation == epoch) setState(() => busy = false);
    }
  }

  String value(dynamic v) {
    if (v is String) return v;
    final l = Localizations.localeOf(context);
    final key = l.languageCode == 'en'
        ? 'en'
        : l.languageCode == 'th'
        ? 'th'
        : l.scriptCode == 'Hant' || {'TW', 'HK', 'MO'}.contains(l.countryCode)
        ? 'zh-TW'
        : 'zh-CN';
    return v[key] as String;
  }

  Future<void> open(SystemNotice n) async {
    if (busy) return;
    if (!n.read) await load(reset: true, read: n.id);
    if (!mounted || failed) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => n.kind == 'partner_message'
            ? _MessageDetail(notice: n, text: value)
            : partnerNoticeDestination(
                n.target?['reference'],
                call: widget.call,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(
        partnerText(context, 'messages'),
        style: const TextStyle(color: Colors.white),
      ),
      centerTitle: true,
    ),
    body: RefreshIndicator(
      onRefresh: () => load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final n in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: const Color(0xff202020),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => open(n),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n.kind == 'partner_message'
                                    ? value(
                                        n.details
                                            .firstWhere((d) => d.$1 == 'title')
                                            .$2,
                                      )
                                    : systemNoticeText(context, n.kind),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            if (!n.read)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.circle,
                                  size: 7,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (n.kind == 'partner_message')
                          Text(
                            value(
                              n.details.firstWhere((d) => d.$1 == 'content').$2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              height: 1.4,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          n.occurredAt.toLocal().toString().split('.').first,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (rows.isEmpty && !busy && !failed)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(child: Text(partnerText(context, 'messagesEmpty'))),
            ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (failed)
            TextButton(
              onPressed: () => load(reset: true),
              child: Text(partnerText(context, 'retry')),
            ),
          if (more && rows.isNotEmpty && !busy)
            TextButton(
              onPressed: load,
              child: Text(partnerText(context, 'more')),
            ),
        ],
      ),
    ),
  );
}

class _MessageDetail extends StatelessWidget {
  const _MessageDetail({required this.notice, required this.text});
  final SystemNotice notice;
  final String Function(dynamic) text;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(
        partnerText(context, 'messages'),
        style: const TextStyle(color: Colors.white),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          text(notice.details.firstWhere((d) => d.$1 == 'title').$2),
          style: const TextStyle(color: Colors.white, fontSize: 24),
        ),
        const SizedBox(height: 12),
        Text(
          notice.occurredAt.toLocal().toString().split('.').first,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 24),
        Text(
          text(notice.details.firstWhere((d) => d.$1 == 'content').$2),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 17,
            height: 1.6,
          ),
        ),
      ],
    ),
  );
}

class PartnerMessageComposer extends StatefulWidget {
  const PartnerMessageComposer({super.key, required this.call});
  final PartnerCall call;
  @override
  State<PartnerMessageComposer> createState() => _ComposerState();
}

class _ComposerState extends State<PartnerMessageComposer> {
  static const locales = ['zh-CN', 'en', 'zh-TW', 'th'];
  final titles = List.generate(4, (_) => TextEditingController());
  final bodies = List.generate(4, (_) => TextEditingController());
  int language = 0;
  bool busy = false, failed = false;
  Map<String, dynamic>? pending;
  @override
  void dispose() {
    for (final c in [...titles, ...bodies]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> publish() async {
    if (busy) return;
    if (pending == null) {
      final missing = List.generate(4, (i) => i).where(
        (i) => titles[i].text.trim().isEmpty || bodies[i].text.trim().isEmpty,
      );
      if (missing.isNotEmpty) {
        setState(() {
          language = missing.first;
          failed = true;
        });
        return;
      }
      pending = {
        'action': 'message_publish',
        'requestId': const Uuid().v4(),
        'titles': {
          for (var i = 0; i < 4; i++) locales[i]: titles[i].text.trim(),
        },
        'contents': {
          for (var i = 0; i < 4; i++) locales[i]: bodies[i].text.trim(),
        },
      };
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.call(pending!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          failed = true;
          if (e is AuthFailure && e.code.startsWith('PARTNER_')) pending = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(
        partnerText(context, 'publishMessage'),
        style: const TextStyle(color: Colors.white),
      ),
      centerTitle: true,
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          partnerText(context, 'messageAudience'),
          style: const TextStyle(color: Colors.white60, height: 1.5),
        ),
        const SizedBox(height: 24),
        DropdownButton<int>(
          value: language,
          isExpanded: true,
          items: List.generate(
            4,
            (i) => DropdownMenuItem(
              value: i,
              child: Text(['简体中文', 'English', '繁體中文', 'ไทย'][i]),
            ),
          ),
          onChanged: (v) => setState(() => language = v!),
        ),
        TextField(
          key: ValueKey('message-title-$language'),
          controller: titles[language],
          readOnly: busy || pending != null,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: partnerText(context, 'messageTitle'),
          ),
        ),
        TextField(
          key: ValueKey('message-content-$language'),
          controller: bodies[language],
          readOnly: busy || pending != null,
          maxLength: 2000,
          minLines: 6,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: partnerText(context, 'messageContent'),
          ),
        ),
        if (failed)
          Text(
            partnerText(context, 'messageFailed'),
            style: const TextStyle(color: Colors.redAccent),
          ),
        const SizedBox(height: 24),
        SizedBox(
          height: kingControlHeight,
          child: FilledButton(
            onPressed: busy ? null : publish,
            child: Text(
              partnerText(
                context,
                pending == null ? 'publishMessage' : 'retry',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
