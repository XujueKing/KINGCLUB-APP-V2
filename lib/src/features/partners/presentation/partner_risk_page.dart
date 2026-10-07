import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

const _background = Color(0xff111111),
    _card = Color(0xff202020),
    _gold = Color(0xffcebea4);
Widget _panel(Widget child) => Container(
  margin: const EdgeInsets.only(bottom: 16),
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: _card,
    borderRadius: BorderRadius.circular(18),
  ),
  child: child,
);
Widget _button(
  String label,
  VoidCallback? onPressed, {
  bool outline = false,
  Key? key,
}) => SizedBox(
  height: 52,
  child: outline
      ? OutlinedButton(
          key: key,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: _gold),
            shape: const StadiumBorder(),
          ),
          onPressed: onPressed,
          child: Text(label),
        )
      : FilledButton(
          key: key,
          style: FilledButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
          ),
          onPressed: onPressed,
          child: Text(label),
        ),
);
bool _yes(dynamic value) => value == true || value == 1;

class PartnerRiskPage extends StatefulWidget {
  const PartnerRiskPage({super.key, required this.call, this.review = false});
  final PartnerCall call;
  final bool review;
  @override
  State<PartnerRiskPage> createState() => _RiskListState();
}

class _RiskListState extends State<PartnerRiskPage> {
  final rows = <Map<String, dynamic>>[];
  bool busy = false,
      failed = false,
      more = true,
      invalid = false,
      canReview = false;
  int page = 0;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) {
        setState(() {
          invalid = true;
          rows.clear();
        });
      }
    });
    load();
  }

  @override
  void dispose() {
    session?.cancel();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (busy || invalid) return;
    setState(() {
      busy = true;
      failed = false;
    });
    final requestedPage = reset ? 0 : page;
    try {
      final result = await widget.call({
        'action': 'risk',
        'review': widget.review ? 1 : 0,
        'page': requestedPage,
      });
      if (!mounted || invalid) return;
      final items = [
        for (final row in result['items'] as List)
          Map<String, dynamic>.from(row as Map),
      ];
      setState(() {
        if (reset) rows.clear();
        rows.addAll(items);
        page = requestedPage + 1;
        more = items.length == 30;
        canReview = widget.review && _yes(result['canReview']);
      });
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void merge(Map<String, dynamic>? result) {
    if (result == null || invalid || !mounted) return;
    final item = Map<String, dynamic>.from(result['item'] as Map);
    setState(() {
      final index = rows.indexWhere((r) => r['ref'] == item['ref']);
      if (index < 0) {
        rows.insert(0, item);
      } else {
        rows[index] = item;
      }
    });
  }

  Future<void> compose() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerRiskForm(call: widget.call, issue: canReview),
      ),
    );
    merge(result);
  }

  Future<void> detail(String ref) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerRiskDetail(
          call: widget.call,
          reference: ref,
          review: widget.review,
        ),
      ),
    );
    merge(result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: kingAppBar(
      context: context,
      title: Text(t(widget.review ? 'riskManagement' : 'risk')),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      top: false,
      child: RefreshIndicator(
        onRefresh: () => load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _panel(
              Text(
                t(widget.review ? 'riskReviewNote' : 'riskNote'),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
            if (!invalid && (!widget.review || canReview)) ...[
              _button(t(canReview ? 'issueRisk' : 'submitComplaint'), compose),
              const SizedBox(height: 20),
            ],
            if (invalid) Text(t('actionFailed')),
            if (busy) const Center(child: CircularProgressIndicator()),
            if (failed) ...[
              Text(t('failed')),
              TextButton(
                onPressed: () => load(reset: rows.isEmpty),
                child: Text(t('retry')),
              ),
            ],
            if (!busy && !failed && rows.isEmpty && !invalid)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    t('riskEmpty'),
                    style: const TextStyle(color: Colors.white60),
                  ),
                ),
              ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: _card,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => detail(row['ref'] as String),
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row['title'] as String,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: Colors.white54,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${t('risk_${row['kind']}')} · ${t('risk_${row['status']}')}',
                            style: const TextStyle(color: _gold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.review ? '${row['memberId']} · ' : ''}${row['date']}',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (rows.isNotEmpty) const SizedBox(height: 16),
            if (more && !busy && rows.isNotEmpty)
              TextButton(onPressed: load, child: Text(t('more'))),
          ],
        ),
      ),
    ),
  );
}

class PartnerRiskDetail extends StatefulWidget {
  const PartnerRiskDetail({
    super.key,
    required this.call,
    required this.reference,
    this.review = false,
  });
  final PartnerCall call;
  final String reference;
  final bool review;
  @override
  State<PartnerRiskDetail> createState() => _RiskDetailState();
}

class _RiskDetailState extends State<PartnerRiskDetail> {
  Map<String, dynamic>? data;
  bool busy = false, failed = false, invalid = false;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) {
        setState(() {
          invalid = true;
          data = null;
        });
      }
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
        'action': 'risk_detail',
        'review': widget.review ? 1 : 0,
        'caseRef': widget.reference,
      });
      if (mounted && !invalid) setState(() => data = result);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(String decision) async {
    final item = Map<String, dynamic>.from(data!['item'] as Map);
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PartnerRiskForm(call: widget.call, decision: decision, item: item),
      ),
    );
    if (mounted && !invalid && result != null) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = data?['item'] as Map?;
    final canReview = widget.review && _yes(data?['canReview']);
    return PopScope<Map<String, dynamic>>(
      canPop: true,
      child: Scaffold(
        backgroundColor: _background,
        appBar: kingAppBar(
          context: context,
          title: Text(t('riskDetail')),
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              if (invalid) Text(t('actionFailed')),
              if (busy) const Center(child: CircularProgressIndicator()),
              if (failed) ...[
                Text(t('failed')),
                TextButton(onPressed: load, child: Text(t('retry'))),
              ],
              if (item != null) ...[
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${t('risk_${item['kind']}')} · ${t('risk_${item['status']}')}',
                        style: const TextStyle(color: _gold, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${item['memberId']}\n${item['date']}',
                        style: const TextStyle(
                          color: Colors.white60,
                          height: 1.6,
                        ),
                      ),
                      const Divider(height: 32, color: Colors.white12),
                      SelectableText(
                        item['description'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                      for (final key in ['relatedReference', 'ruleReference'])
                        if ((item[key] as String? ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: SelectableText(
                              '${t(key)}\n${item[key]}',
                              style: const TextStyle(
                                color: Colors.white70,
                                height: 1.5,
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),
                      SelectableText(
                        '${t('caseReference')}\n${item['ref']}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final event in data!['events'] as List)
                  _panel(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('risk_action_${event['kind']}'),
                          style: const TextStyle(color: _gold, fontSize: 16),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          event['reason'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${event['operator']} · ${event['date']}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (canReview && item['status'] == 'open')
                  Row(
                    children: [
                      Expanded(
                        child: _button(
                          t('dismissCase'),
                          () => action('dismiss'),
                          outline: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _button(
                          t('resolveCase'),
                          () => action('resolve'),
                        ),
                      ),
                    ],
                  ),
                if (canReview && item['status'] == 'restricted')
                  _button(t('restorePartner'), () => action('restore')),
                if (!widget.review && _yes(data?['canAppeal']))
                  _button(
                    t('submitAppeal'),
                    () => action('appeal'),
                    outline: true,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class PartnerRiskForm extends StatefulWidget {
  const PartnerRiskForm({
    super.key,
    required this.call,
    this.issue = false,
    this.decision,
    this.item,
  });
  final PartnerCall call;
  final bool issue;
  final String? decision;
  final Map<String, dynamic>? item;
  @override
  State<PartnerRiskForm> createState() => _RiskFormState();
}

class _RiskFormState extends State<PartnerRiskForm> {
  final title = TextEditingController(),
      description = TextEditingController(),
      reference = TextEditingController(),
      rule = TextEditingController(),
      member = TextEditingController();
  String choice = 'warn';
  bool busy = false, invalid = false;
  Map<String, dynamic>? pending;
  String? error;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  bool get reasonOnly =>
      ['resolve', 'dismiss', 'restore'].contains(widget.decision);
  String get heading => widget.issue
      ? 'issueRisk'
      : widget.decision == 'appeal'
      ? 'submitAppeal'
      : reasonOnly
      ? 'riskDecision'
      : 'submitComplaint';
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) setState(() => invalid = true);
    });
  }

  @override
  void dispose() {
    session?.cancel();
    for (final c in [title, description, reference, rule, member]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || invalid) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (pending == null) {
      if (description.text.trim().length < 10 ||
          (!reasonOnly && title.text.trim().isEmpty) ||
          (widget.issue &&
              (!RegExp(r'^KM[0-9A-Z]{1,62}$')
                      .hasMatch(member.text.trim().toUpperCase()) ||
                  rule.text.trim().isEmpty))) {
        setState(() => error = t('riskRequired'));
        return;
      }
      if (widget.issue || reasonOnly) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: _card,
            title: Text(t('riskDecision')),
            content: Text(
              t('riskConfirm'),
              style: const TextStyle(height: 1.5),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: _button(
                      t('cancel'),
                      () => Navigator.pop(context, false),
                      outline: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _button(
                      t('confirm'),
                      () => Navigator.pop(context, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (!mounted || invalid || confirmed != true) return;
      }
      pending = {
        'action': widget.issue
            ? 'risk_issue'
            : reasonOnly
            ? widget.decision == 'restore'
                  ? 'risk_restore'
                  : 'risk_decide'
            : 'risk_submit',
        'requestId': const Uuid().v4(),
        if (widget.issue || reasonOnly) 'review': 1,
        if (widget.issue) ...{
          'memberId': member.text.trim().toUpperCase(),
          'decision': choice,
          'ruleReference': rule.text.trim(),
        },
        if (reasonOnly) ...{
          'caseRef': widget.item!['ref'],
          'expectedVersion': widget.item!['version'],
          if (widget.decision != 'restore') 'decision': widget.decision,
          'reason': description.text.trim(),
        } else ...{
          'title': title.text.trim(),
          'description': description.text.trim(),
          'relatedReference': reference.text.trim(),
          if (!widget.issue)
            'kind': widget.decision == 'appeal' ? 'appeal' : 'complaint',
          if (widget.decision == 'appeal') 'parentCaseRef': widget.item!['ref'],
        },
      };
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.call(pending!);
      if (result['receiptRef'] != pending!['requestId'] ||
          result['item'] is! Map) {
        throw StateError('Missing case receipt');
      }
      if (mounted && !invalid) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) setState(() => error = t('riskFailed'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(
    TextEditingController controller,
    String label,
    int max, {
    int lines = 1,
  }) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(label),
          style: const TextStyle(color: Colors.white60, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey('partner-risk-$label'),
          controller: controller,
          readOnly: busy || pending != null || invalid,
          maxLength: max,
          maxLines: lines,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
          cursorColor: _gold,
          decoration: const InputDecoration(
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            counterStyle: TextStyle(color: Colors.white38),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _background,
    appBar: kingAppBar(
      context: context,
      title: Text(t(heading)),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          if (widget.issue) ...[
            input(member, 'memberId', 64),
            input(rule, 'ruleReference', 80),
            _panel(
              Wrap(
                spacing: 16,
                children: [
                  for (final value in ['warn', 'suspend'])
                    ChoiceChip(
                      label: Text(t('risk_action_$value')),
                      selected: choice == value,
                      side: BorderSide.none,
                      selectedColor: _gold,
                      labelStyle: TextStyle(
                        color: choice == value ? Colors.black : Colors.white70,
                      ),
                      onSelected: busy || pending != null || invalid
                          ? null
                          : (_) => setState(() => choice = value),
                    ),
                ],
              ),
            ),
          ],
          if (!reasonOnly) input(title, 'riskTitle', 80),
          input(
            description,
            reasonOnly ? 'riskReason' : 'riskDescription',
            2000,
            lines: 6,
          ),
          if (!reasonOnly) input(reference, 'relatedReference', 128),
          Text(
            t('riskPrivacyNote'),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.6,
            ),
          ),
          if (error != null || invalid)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                invalid ? t('actionFailed') : error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          const SizedBox(height: 20),
          _button(
            t(pending != null ? 'retry' : 'submit'),
            busy || invalid ? null : submit,
            key: const ValueKey('partner-risk-submit'),
          ),
        ],
      ),
    ),
  );
}
