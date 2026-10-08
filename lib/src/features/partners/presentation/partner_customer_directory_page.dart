import 'package:kingclub/src/core/design_system/king_input_style.dart';
import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../data/partner_repository.dart';
import 'customer_components.dart';
import 'partner_customer_detail_page.dart';
import 'partner_collaborator_detail_page.dart';
import 'collaborator_components.dart';
import '../../home/data/home_city_catalog.dart';
import '../../home/presentation/home_city_page.dart';

class PartnerCustomerDirectoryPage extends StatefulWidget {
  const PartnerCustomerDirectoryPage({
    super.key,
    required this.call,
    this.partnersOnly = false,
  });
  final PartnerCall call;
  final bool partnersOnly;
  @override
  State<PartnerCustomerDirectoryPage> createState() => _DirectoryState();
}

class _DirectoryState extends State<PartnerCustomerDirectoryPage> {
  final search = TextEditingController();
  final items = <Map<String, dynamic>>[];
  static const categories = ['members', 'pending', 'blacklist'];
  HomeCity? city;
  String category = 'members', filter = 'all', query = '';
  int page = 0, total = 0, epoch = 0;
  bool busy = false, failed = false, more = false;
  String t(String key) => customerText(context, key);
  @override
  void initState() {
    super.initState();
    load(reset: true);
  }

  @override
  void dispose() {
    epoch++;
    search.dispose();
    super.dispose();
  }

  Future<void> load({bool reset = false}) async {
    if (busy && !reset) return;
    final generation = ++epoch;
    if (reset) {
      page = 0;
      items.clear();
      total = 0;
      more = false;
    }
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final r = await widget.call({
        'action': widget.partnersOnly ? 'partners_directory' : 'directory',
        if (!widget.partnersOnly) 'category': category,
        'cityCode': ?city?.code,
        'filter': filter,
        'query': query,
        'page': page,
      });
      if (!mounted || generation != epoch) return;
      setState(() {
        items.addAll(
          (r['items'] as List).map((v) => Map<String, dynamic>.from(v as Map)),
        );
        total = (r['total'] as num).toInt();
        more = r['hasMore'] == true || r['hasMore'] == 1;
        page++;
      });
    } catch (_) {
      if (mounted && generation == epoch) setState(() => failed = true);
    } finally {
      if (mounted && generation == epoch) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, dynamic> item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => widget.partnersOnly
            ? PartnerCollaboratorDetailPage(
                call: widget.call,
                targetAccount: item['ref'] as String,
              )
            : PartnerCustomerDetailPage(
                call: widget.call,
                targetAccount: item['ref'] as String,
              ),
      ),
    );
    if (mounted) await load(reset: true);
  }

  Future<void> selectCity() async {
    FocusScope.of(context).unfocus();
    final result = await chooseCityScope(context, current: city);
    if (!mounted || result == null) return;
    setState(() => city = result.city);
    await load(reset: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff111111),
    appBar: kingAppBar(
      context: context,
      title: Text(t(widget.partnersOnly ? 'partnersDirectory' : 'directory')),
      foregroundColor: Colors.white,
      centerTitle: true,
    ),
    body: SafeArea(
      child: Column(
        children: [
          if (!widget.partnersOnly)
            CustomerTabs(
              fontSize: 17,
              labels: [for (final c in categories) t(c)],
              onTap: (i) {
                category = categories[i];
                load(reset: true);
              },
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('customer-search'),
                    controller: search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      query = search.text.trim();
                      FocusScope.of(context).unfocus();
                      load(reset: true);
                    },
                    style: kingSearchTextStyle,
                    decoration: kingSearchDecoration(
                      hintText: t('search'),
                      prefixIcon: null,
                      suffixIcon: IconButton(
                        tooltip: t('searchAction'),
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          query = search.text.trim();
                          FocusScope.of(context).unfocus();
                          load(reset: true);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                PopupMenuButton<String>(
                  initialValue: filter,
                  onSelected: (value) {
                    filter = value;
                    load(reset: true);
                  },
                  itemBuilder: (_) => [
                    for (final f in [
                      'all',
                      'reserved',
                      'arrived',
                      'male',
                      'female',
                    ])
                      PopupMenuItem(value: f, child: Text(t(f))),
                  ],
                  child: SizedBox(
                    height: kingControlHeight,
                    child: Row(
                      children: [
                        Text(t(filter), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        const Icon(Icons.keyboard_arrow_down, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: TextButton(
                    key: const ValueKey('customer-city-selector'),
                    onPressed: selectCity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            city?.shortName ?? t('allCities'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${t(widget.partnersOnly ? 'partnerCount' : 'count')}：${busy && items.isEmpty ? '—' : total}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => load(reset: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  for (final item in items)
                    InkWell(
                      key: ValueKey('customer-${item['ref']}'),
                      onTap: () => open(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            if (widget.partnersOnly)
                              collaboratorDirectoryRow(context, item)
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  CustomerAvatar(customer: item),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (widget.partnersOnly)
                                          collaboratorName(context, item)
                                        else
                                          customerName(item),
                                        const SizedBox(height: 6),
                                        Text(
                                          customerDate(item['date']),
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        widget.partnersOnly
                                            ? collaboratorLevel(item)
                                            : item['levelName'] as String? ??
                                                  '—',
                                        style: const TextStyle(
                                          color: customerGold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item['phone'] as String? ?? '—',
                                        style: const TextStyle(
                                          color: Colors.white60,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Divider(height: 1, color: Colors.white12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (!busy && failed)
                    Center(
                      child: TextButton(
                        onPressed: () => load(reset: items.isEmpty),
                        child: Text(t('failed')),
                      ),
                    ),
                  if (!busy && !failed && items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(child: Text(t('empty'))),
                    ),
                  if (!busy && !failed && more)
                    TextButton(onPressed: load, child: Text(t('more'))),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
