import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../../core/session/secure_session_store.dart';
import '../../../core/formatters/money.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';
import '../../home/data/home_city_catalog.dart';
import '../../home/data/home_city_location.dart';
import '../../home/presentation/home_city_page.dart';
import 'partner_code_page.dart';
import 'partner_tasks_page.dart';
import 'partner_policy_page.dart';
import 'partner_transfer_page.dart';
import 'partner_withdrawal_page.dart';
import '../../scanner/presentation/member_scanner_page.dart';

Widget _title(BuildContext context, String value) => Text(
  value,
  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
);

const _card = Color(0xff202020), _gold = Color(0xffcebea4);

class PartnerPlatformPage extends StatefulWidget {
  const PartnerPlatformPage({super.key, this.call, this.onViewed});
  final VoidCallback? onViewed;
  final PartnerCall? call;
  @override
  State<PartnerPlatformPage> createState() => _PartnerPlatformPageState();
}

class _PartnerPlatformPageState extends State<PartnerPlatformPage> {
  late final PartnerCall call = widget.call ?? PartnerRepository().call;
  PartnerContext? data;
  bool busy = false, failed = false;
  int epoch = 0;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null) Navigator.of(context).popUntil((r) => r == route);
      epoch++;
      setState(() {
        data = null;
        busy = false;
        failed = false;
      });
      load();
    });
    load();
  }

  @override
  void dispose() {
    epoch++;
    session?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (busy) return;
    final generation = ++epoch;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = PartnerContext(await call({'action': 'context'}));
      if (mounted && epoch == generation) {
        setState(() => data = result);
        if (result.partner != null) widget.onViewed?.call();
      }
    } catch (_) {
      if (mounted && epoch == generation) setState(() => failed = true);
    } finally {
      if (mounted && epoch == generation) setState(() => busy = false);
    }
  }

  Future<void> apply() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _ApplicationPage(call: call)),
    );
    if (mounted) await load();
  }

  void list(String kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PartnerListPage(kind: kind, call: call),
    ),
  );
  void tasks(String kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PartnerTasksPage(call: call, kind: kind),
    ),
  );
  void levels() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: _card,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(c).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              t('levels'),
              style: const TextStyle(fontSize: 22, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              t('rateNote'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
            for (var n = 1; n <= 15; n++)
              ListTile(title: Text('L$n'), trailing: Text('${n + 5}%')),
            const Divider(),
            Text(
              t('eligibleNote'),
              style: const TextStyle(color: Colors.white70, height: 1.5),
            ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final d = data;
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: _title(context, t('title')),
        foregroundColor: Colors.white,
        centerTitle: true,
        backgroundColor: const Color(0xff111111),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              if (busy && d == null)
                const Padding(
                  padding: EdgeInsets.all(64),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (failed)
                _panel(
                  Column(
                    children: [
                      Text(t('failed')),
                      TextButton(
                        onPressed: busy ? null : load,
                        child: Text(t('retry')),
                      ),
                    ],
                  ),
                ),
              if (d != null && d.admin)
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(t('withdrawReview')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          PartnerWithdrawalPage(call: call, review: true),
                    ),
                  ),
                ),
              if (d != null && d.partner == null) ...[
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        color: _gold,
                        size: 42,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        t(
                          d.application?['status'] == 'pending'
                              ? 'pending'
                              : d.application?['status'] == 'rejected'
                              ? 'rejected'
                              : 'join',
                        ),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        t('intro'),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      if ((d.application?['reason'] as String? ?? '')
                          .isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(d.application!['reason'] as String),
                        ),
                      if (d.application?['status'] != 'pending') ...[
                        const SizedBox(height: 24),
                        _button(t('join'), apply),
                      ],
                    ],
                  ),
                ),
              ],
              if (d?.partner != null) ...[
                ListTile(
                  contentPadding: const EdgeInsets.only(bottom: 16),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xff302a21),
                    child: Icon(Icons.handshake_outlined, color: _gold),
                  ),
                  title: Text('${t('title')} · L${d!.partner!['level']}'),
                  subtitle: Text(
                    '${t('rate')} ${(d.partner!['organizerBps'] as num).toInt() ~/ 100}%',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: levels,
                ),
                if (d.partner!['status'] == 'suspended')
                  _panel(Text(t('suspended'))),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t('earnings'), style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(
                        d.finance == null
                            ? '—'
                            : '¥${moneyCents(d.finance!['availableCents'])}',
                        style: const TextStyle(fontSize: 34),
                      ),
                      if (d.finance != null)
                        Text(
                          '${t('pendingReward')}  ¥${moneyCents(d.finance!['pendingCents'])}',
                        ),
                      Text(
                        t(
                          d.finance == null
                              ? 'financePending'
                              : 'taskLedgerNote',
                        ),
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: d.partner?['status'] == 'active'
                                  ? () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PartnerWithdrawalPage(call: call),
                                        ),
                                      );
                                      if (mounted) await load();
                                    }
                                  : null,
                              child: Text(
                                t('withdraw'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: d.partner?['status'] == 'active'
                                  ? () async {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              PartnerTransferPage(call: call),
                                        ),
                                      );
                                      if (mounted) await load();
                                    }
                                  : null,
                              child: Text(
                                t('transfer'),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _panel(
                  Column(
                    children: [
                      _entry(
                        'code',
                        Icons.qr_code_2,
                        onTap: d.partner!['status'] == 'active'
                            ? () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => PartnerCodePage(call: call),
                                ),
                              )
                            : null,
                      ),
                      _entry(
                        'tasks',
                        Icons.assignment_outlined,
                        onTap: () => tasks('tasks'),
                      ),
                    ],
                  ),
                ),
                _panel(
                  Column(
                    children: [
                      _entry(
                        'team',
                        Icons.groups_outlined,
                        onTap: () => list('team'),
                        sub: '${t('direct')} · ${d.teamCount}',
                      ),
                      _entry(
                        'customers',
                        Icons.person_outline,
                        onTap: () => list('customers'),
                        sub: '${d.customerCount}',
                      ),
                      _entry(
                        'commission',
                        Icons.receipt_long_outlined,
                        onTap: () => tasks('ledger'),
                      ),
                    ],
                  ),
                ),
              ],
              if (d?.admin == true)
                _panel(
                  Column(
                    children: [
                      _entry(
                        'tasks',
                        Icons.assignment_outlined,
                        onTap: () => tasks('tasks'),
                      ),
                      _entry(
                        'task_reviews',
                        Icons.fact_check_outlined,
                        onTap: () => tasks('task_reviews'),
                      ),
                      _entry(
                        'applications',
                        Icons.fact_check_outlined,
                        onTap: () => list('applications'),
                      ),
                      _entry(
                        'directory',
                        Icons.contacts_outlined,
                        onTap: () => list('directory'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _entry(
    String key,
    IconData icon, {
    VoidCallback? onTap,
    String? sub,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: _gold),
    title: Text(t(key)),
    subtitle: sub == null
        ? null
        : Text(
            sub,
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
    trailing: onTap == null ? null : const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

Widget _panel(Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Material(
    color: _card,
    borderRadius: BorderRadius.circular(14),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  ),
);
Widget _button(String label, VoidCallback? onTap) => SizedBox(
  width: double.infinity,
  height: kingControlHeight,
  child: FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: _gold,
      foregroundColor: Colors.black,
    ),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(fontSize: 16)),
  ),
);

class _ApplicationPage extends StatefulWidget {
  const _ApplicationPage({required this.call});
  final PartnerCall call;
  @override
  State<_ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<_ApplicationPage> {
  final intro = TextEditingController();
  final referrerInput = TextEditingController();
  Map<String, dynamic>? referrer;
  bool checkingReferrer = false;
  HomeCity? city = HomeCitySession.current;
  @override
  void initState() {
    super.initState();
    if (city == null) resolveCity();
  }

  Future<void> resolveCity() async {
    try {
      final catalog = await HomeCityCatalog.load();
      final name = await locateHomeCity();
      if (mounted && city == null && pending == null) {
        setState(
          () => city = HomeCitySession.current ?? catalog.namedCity(name),
        );
      }
    } catch (_) {
      /* Manual selection remains available. */
    }
  }

  Future<void> selectCity() async {
    if (busy || pending != null) return;
    final catalog = await HomeCityCatalog.load();
    if (!mounted || busy || pending != null) return;
    final selected = await Navigator.push<HomeCity>(
      context,
      MaterialPageRoute(
        builder: (_) => HomeCityPage(
          catalog: catalog,
          current: city,
          located: HomeCitySession.current,
        ),
      ),
    );
    if (mounted && selected != null && pending == null) {
      setState(() => city = selected);
    }
  }

  final directions = <String>{};
  Map<String, dynamic>? pending;
  bool busy = false;
  String? error;
  String t(String k) => partnerText(context, k);
  @override
  void dispose() {
    intro.dispose();
    referrerInput.dispose();
    super.dispose();
  }

  Future<bool> verifyReferrer({String? code}) async {
    if (busy || checkingReferrer || pending != null) return false;
    final memberId = referrerInput.text.trim().toUpperCase();
    if (code == null && !RegExp(r'^KM[0-9A-Z]{1,62}$').hasMatch(memberId)) {
      setState(() => error = t('invalidReferrer'));
      return false;
    }
    setState(() {
      checkingReferrer = true;
      error = null;
      referrer = null;
    });
    try {
      final result = await widget.call({
        'action': 'referrer',
        if (code != null) 'code': code else 'memberId': memberId,
      });
      if (!mounted) return false;
      final candidate = Map<String, dynamic>.from(result['referrer'] as Map);
      if (!RegExp(r'^KM[0-9A-Z]{1,62}$')
              .hasMatch(candidate['memberId'] as String) ||
          candidate['name'] is! String ||
          candidate['level'] is! int) {
        throw const FormatException('Invalid referrer');
      }
      setState(() {
        referrer = candidate;
        referrerInput.text = candidate['memberId'] as String;
      });
      return true;
    } catch (_) {
      if (mounted) setState(() => error = t('invalidReferrer'));
      return false;
    } finally {
      if (mounted) setState(() => checkingReferrer = false);
    }
  }

  Future<void> scanReferrer() async {
    if (busy || checkingReferrer || pending != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const MemberScannerPage(pickReferrer: true),
      ),
    );
    if (mounted && code != null) await verifyReferrer(code: code);
  }

  Future<void> submit() async {
    if (busy || checkingReferrer) return;
    if (pending == null && (city == null || directions.isEmpty)) {
      setState(() => error = t('required'));
      return;
    }
    if (pending == null &&
        referrerInput.text.trim().isNotEmpty &&
        referrer?['memberId'] != referrerInput.text.trim().toUpperCase()) {
      if (!await verifyReferrer()) return;
      if (!mounted) return;
    }
    pending ??= {
      'action': 'apply',
      'requestId': const Uuid().v4(),
      'city': city!.name,
      'directions': directions.toList()..sort(),
      'introduction': intro.text.trim(),
      if (referrer != null) 'referrerMemberId': referrer!['memberId'],
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.call(pending!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = t('actionFailed'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: _title(context, t('join')),
      backgroundColor: const Color(0xff111111),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: const Color(0xff1c1c1e),
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: const ValueKey('partner-city-choice'),
              onTap: busy || pending != null ? null : selectCity,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                child: Column(
                  children: [
                    Text(
                      t('city'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      city?.name ?? t('chooseCity'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xff1c1c1e),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('applicationReferrer'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('partner-referrer-input'),
                  controller: referrerInput,
                  readOnly: busy || checkingReferrer || pending != null,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 64,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: t('referrerPlaceholder'),
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() => referrer = null),
                  onSubmitted: (_) => verifyReferrer(),
                ),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy || checkingReferrer || pending != null
                          ? null
                          : scanReferrer,
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: Text(t('scanReferrer')),
                    ),
                    TextButton(
                      onPressed: busy || checkingReferrer || pending != null
                          ? null
                          : () => verifyReferrer(),
                      child: Text(
                        checkingReferrer ? t('saving') : t('verifyReferrer'),
                      ),
                    ),
                  ],
                ),
                if (referrer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${referrer!['name']} · ${referrer!['memberId']}\n${t('referrerLevel')} ${referrer!['level']}',
                      style: const TextStyle(
                        color: _gold,
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  t('directions'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final key in ['organize', 'members', 'merchants'])
                      FilterChip(
                        label: Text(t(key)),
                        labelStyle: TextStyle(
                          color: directions.contains(key)
                              ? const Color(0xff111111)
                              : Colors.white70,
                          fontSize: 15,
                        ),
                        backgroundColor: const Color(0xff2b2b2e),
                        selectedColor: _gold,
                        checkmarkColor: const Color(0xff111111),
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
                        selected: directions.contains(key),
                        onSelected: pending != null
                            ? null
                            : (v) => setState(() {
                                v
                                    ? directions.add(key)
                                    : directions.remove(key);
                              }),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            decoration: BoxDecoration(
              color: const Color(0xff1c1c1e),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('experience'),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: intro,
                  readOnly: pending != null,
                  maxLines: 4,
                  maxLength: 500,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  cursorColor: _gold,
                  decoration: const InputDecoration(
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    counterStyle: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          const SizedBox(height: 20),
          _button(
            pending != null ? t('retry') : t('submit'),
            busy || checkingReferrer ? null : submit,
          ),
        ],
      ),
    ),
  );
}

class _PartnerListPage extends StatefulWidget {
  const _PartnerListPage({
    required this.kind,
    required this.call,
    this.teamAccount,
    this.teamName,
  });
  final String kind;
  final String? teamAccount, teamName;
  final PartnerCall call;
  @override
  State<_PartnerListPage> createState() => _PartnerListState();
}

class _PartnerListState extends State<_PartnerListPage> {
  final items = <Map<String, dynamic>>[];
  int page = 0;
  bool busy = false, failed = false, more = true;
  String t(String k) => partnerText(context, k);
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final r = await widget.call({
        'action': widget.kind,
        'page': page,
        if (widget.teamAccount != null) 'teamAccount': widget.teamAccount,
      });
      final rows = (r['items'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      if (mounted) {
        setState(() {
          items.addAll(rows);
          page++;
          more = rows.length == 30;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> review(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PartnerApplicationReviewForm(item: item, call: widget.call),
      ),
    );
    if (mounted) {
      items.clear();
      page = 0;
      more = true;
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: _title(context, t(widget.kind)),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.teamName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                widget.teamName!,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          if (widget.kind == 'team')
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                t('treeNote'),
                style: const TextStyle(color: Colors.white60),
              ),
            ),
          for (final item in items)
            _panel(
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item['name'] as String),
                subtitle: Text(
                  [item['city'], item['date']].whereType<String>().join('\n'),
                ),
                trailing: widget.kind == 'applications'
                    ? const Icon(Icons.chevron_right)
                    : item['level'] == null
                    ? null
                    : Text('L${item['level']}'),
                onTap: widget.kind == 'applications'
                    ? () => review(item)
                    : widget.kind == 'team'
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => _PartnerListPage(
                            kind: 'team',
                            call: widget.call,
                            teamAccount: item['ref'] as String,
                            teamName: item['name'] as String,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          if (!busy && !failed && items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text(t('empty'))),
            ),
          if (busy) const Center(child: CircularProgressIndicator()),
          if (failed)
            TextButton(
              onPressed: load,
              child: Text('${t('failed')} · ${t('retry')}'),
            ),
          if (!busy && !failed && more)
            TextButton(onPressed: load, child: Text(t('more'))),
        ],
      ),
    ),
  );
}

class PartnerApplicationReviewForm extends StatefulWidget {
  const PartnerApplicationReviewForm({
    super.key,
    required this.item,
    required this.call,
  });
  final Map<String, dynamic> item;
  final PartnerCall call;
  @override
  State<PartnerApplicationReviewForm> createState() => _ReviewState();
}

class _ReviewState extends State<PartnerApplicationReviewForm> {
  final reason = TextEditingController();
  bool busy = false;
  Map<String, dynamic>? pending;
  String? error;
  String t(String k) => partnerText(context, k);
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> send(String decision) async {
    if (busy ||
        widget.item['status'] != 'pending' ||
        reason.text.trim().isEmpty) {
      return;
    }
    pending ??= {
      'action': 'review',
      'requestId': const Uuid().v4(),
      'applicationRef': widget.item['ref'],
      'decision': decision,
      'reason': reason.text.trim(),
    };
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.call(pending!);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => error = t('actionFailed'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: kingAppBar(
      context: context,
      title: _title(context, t('applications')),
      backgroundColor: const Color(0xFF111111),
      centerTitle: true,
    ),
    backgroundColor: const Color(0xFF111111),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.item['name'] as String,
          style: const TextStyle(fontSize: 22),
        ),
        Text('${widget.item['city']}'),
        Text('${widget.item['introduction']}'),
        Text(
          (widget.item['directions'] as List? ?? [])
              .map((v) => t('$v'))
              .join(' · '),
        ),
        const SizedBox(height: 12),
        Text(t(widget.item['status'] as String)),
        const SizedBox(height: 16),
        Text(
          t('applicationReferrer'),
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 8),
        if (widget.item['referrer'] is Map)
          Text(
            '${widget.item['referrer']['name']}\n${widget.item['referrer']['memberId']} · ${t('referrerLevel')} ${widget.item['referrer']['level']}',
            style: const TextStyle(fontSize: 17, height: 1.5),
          )
        else
          Text(t('directApplication'), style: const TextStyle(fontSize: 16)),
        if (widget.item['status'] != 'pending')
          Text('${widget.item['reason'] ?? ''}'),
        if (widget.item['status'] == 'pending') ...[
          const SizedBox(height: 20),
          TextField(
            controller: reason,
            readOnly: pending != null,
            maxLength: 300,
            decoration: InputDecoration(labelText: t('reviewReason')),
          ),
          if (error != null) Text(error!),
          const SizedBox(height: 20),
          _button(
            pending == null ? t('approve') : t('retry'),
            busy ? null : () => send('approved'),
          ),
          if (pending == null) ...[
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: kingControlHeight,
              child: OutlinedButton(
                key: const ValueKey('partner-review-reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: const BorderSide(color: _gold),
                  shape: kingActionButtonShape,
                  textStyle: const TextStyle(fontSize: 16),
                ),
                onPressed: busy ? null : () => send('rejected'),
                child: Text(t('reject')),
              ),
            ),
          ],
        ],
      ],
    ),
  );
}

class _MerchantPage extends StatefulWidget {
  const _MerchantPage({required this.store, required this.call});
  final Map<String, dynamic> store;
  final PartnerCall call;
  @override
  State<_MerchantPage> createState() => _MerchantState();
}

class _MerchantState extends State<_MerchantPage> {
  late Future<Map<String, dynamic>> result = widget.call({
    'action': 'merchant',
    'storeRef': widget.store['ref'],
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: _title(context, partnerText(context, 'merchant')),
      centerTitle: true,
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: partnerText(context, 'title'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.swap_horiz),
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: result,
      builder: (c, s) {
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => result = widget.call({
                  'action': 'merchant',
                  'storeRef': widget.store['ref'],
                }),
              ),
              child: Text(partnerText(c, 'retry')),
            ),
          );
        }
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final store = s.data!['store'] as Map;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.storefront_outlined, color: _gold, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    store['name'] as String,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 16),
                  Text('${partnerText(c, 'address')}\n${store['address']}'),
                  const SizedBox(height: 16),
                  Text('${partnerText(c, 'currency')} · ${store['currency']}'),
                  if (store['currency'] == 'CNY') ...[
                    const SizedBox(height: 20),
                    _button(
                      partnerText(c, 'commissionPolicy'),
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => PartnerPolicyPage(
                            call: widget.call,
                            storeRef: widget.store['ref'] as String,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              partnerText(c, 'merchantNote'),
              style: const TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 20),
            _button(
              partnerText(c, 'tasks'),
              () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PartnerTasksPage(
                    call: widget.call,
                    storeRef: widget.store['ref'] as String,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> openMerchantPlatform(
  BuildContext context,
  List<Map<String, dynamic>> stores, {
  PartnerCall? call,
}) async {
  if (stores.isEmpty) return;
  final api = call ?? PartnerRepository().call;
  Map<String, dynamic>? selected;
  if (stores.length == 1) {
    selected = stores.single;
  } else {
    selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: _card,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final store in stores)
              ListTile(
                leading: const Icon(Icons.storefront_outlined, color: _gold),
                title: Text(store['name'] as String),
                onTap: () => Navigator.pop(c, store),
              ),
          ],
        ),
      ),
    );
  }
  if (!context.mounted || selected == null) return;
  await Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => _MerchantPage(store: selected!, call: api),
    ),
  );
}
