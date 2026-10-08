import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../../core/design_system/king_input_style.dart';
import '../../home/data/home_city_catalog.dart';
import '../../home/presentation/home_city_page.dart';
import '../data/partner_repository.dart';
import 'collaborator_components.dart';
import 'customer_components.dart';

class PartnerAssignmentPage extends StatefulWidget {
  const PartnerAssignmentPage({
    super.key,
    required this.call,
    required this.partner,
  });
  final PartnerCall call;
  final Map<String, dynamic> partner;
  @override
  State<PartnerAssignmentPage> createState() => _AssignmentState();
}

class _AssignmentState extends State<PartnerAssignmentPage> {
  late String role;
  String? code, name, request;
  final reason = TextEditingController();
  bool busy = false, failed = false;
  String t(String key) => collaboratorText(context, key);
  @override
  void initState() {
    super.initState();
    role = widget.partner['partnerRole'] as String;
    code =
        widget.partner[role == 'provincial'
                ? 'coverageProvinceCode'
                : 'coverageCityCode']
            as String?;
    name =
        widget.partner[role == 'provincial'
                ? 'coverageProvince'
                : 'coverageCity']
            as String?;
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  void changed() {
    request = null;
    failed = false;
  }

  Future<void> choose() async {
    FocusScope.of(context).unfocus();
    final catalog = await HomeCityCatalog.load();
    if (!mounted) return;
    final HomeCity? selected = await Navigator.push<HomeCity>(
      context,
      MaterialPageRoute(
        builder: (_) => role == 'provincial'
            ? _ProvincePage(catalog: catalog)
            : HomeCityPage(catalog: catalog, current: catalog.byCode[code]),
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      code = selected.code;
      name = selected.name;
      changed();
    });
  }

  Future<void> save() async {
    if (busy ||
        reason.text.trim().isEmpty ||
        (role != 'collaborator' && code == null)) {
      return;
    }
    FocusScope.of(context).unfocus();
    request ??= const Uuid().v4();
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await widget.call({
        'action': 'collaborator_assign',
        'targetAccount': widget.partner['ref'],
        'requestId': request,
        'expectedVersion': widget.partner['roleVersion'] ?? 0,
        'role': role,
        if (role != 'collaborator') 'coverageCode': code,
        'reason': reason.text.trim(),
      });
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(t('assignment')),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomerPanel(
              child: collaboratorName(context, widget.partner, size: 20),
            ),
            CustomerPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('identity'),
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  PopupMenuButton<String>(
                    key: const ValueKey('assignment-role'),
                    enabled: !busy,
                    onSelected: (value) => setState(() {
                      role = value;
                      code = null;
                      name = null;
                      changed();
                    }),
                    itemBuilder: (_) => [
                      for (final value in [
                        'collaborator',
                        'regional',
                        'provincial',
                      ])
                        PopupMenuItem(value: value, child: Text(t(value))),
                    ],
                    child: SizedBox(
                      width: double.infinity,
                      height: kingControlHeight,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              t(role),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: customerGold,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (role != 'collaborator') ...[
                    const Divider(color: Colors.white12),
                    Text(
                      t('coverage'),
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('assignment-region'),
                      onPressed: busy ? null : choose,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              name ??
                                  t(
                                    role == 'provincial'
                                        ? 'chooseProvince'
                                        : 'chooseRegion',
                                  ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: customerGold,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            TextField(
              key: const ValueKey('assignment-reason'),
              controller: reason,
              enabled: !busy,
              maxLength: 300,
              minLines: 3,
              maxLines: 5,
              onChanged: (_) => setState(changed),
              style: kingSearchTextStyle,
              decoration: kingSearchDecoration(
                hintText: t('assignmentReason'),
                prefixIcon: null,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              t('assignmentScope'),
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (failed)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  customerText(context, 'stateFailed'),
                  style: const TextStyle(color: customerGold, fontSize: 16),
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              height: kingControlHeight,
              child: FilledButton(
                key: const ValueKey('assignment-save'),
                style: FilledButton.styleFrom(
                  shape: kingActionButtonShape,
                  backgroundColor: customerGold,
                  foregroundColor: Colors.black,
                ),
                onPressed:
                    busy ||
                        reason.text.trim().isEmpty ||
                        (role != 'collaborator' && code == null)
                    ? null
                    : save,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        t('saveAssignment'),
                        style: const TextStyle(fontSize: 17),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProvincePage extends StatelessWidget {
  const _ProvincePage({required this.catalog});
  final HomeCityCatalog catalog;
  @override
  Widget build(BuildContext context) {
    final provinces = catalog.cities
        .where((c) => !c.code.startsWith('INT_') && c.code.endsWith('0000'))
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        title: Text(collaboratorText(context, 'chooseProvince')),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: ListView(
        key: const ValueKey('assignment-province-list'),
        padding: const EdgeInsets.all(16),
        children: [
          for (final province in provinces)
            ListTile(
              title: Text(
                province.name,
                style: const TextStyle(fontSize: 17, color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, province),
            ),
        ],
      ),
    );
  }
}
