import 'package:flutter/material.dart';

import '../data/home_city_catalog.dart';
import '../../messaging/presentation/legacy_messaging_components.dart';

String homeCopy(
  BuildContext context,
  String cn,
  String en,
  String tw,
  String th,
) {
  final l = Localizations.localeOf(context);
  return l.languageCode == 'en'
      ? en
      : l.languageCode == 'th'
      ? th
      : l.scriptCode == 'Hant' || {'TW', 'HK', 'MO'}.contains(l.countryCode)
      ? tw
      : cn;
}

class HomeCityPage extends StatefulWidget {
  const HomeCityPage({
    super.key,
    required this.catalog,
    this.current,
    this.located,
    this.history = const HomeCityHistory(),
  });
  final HomeCityCatalog catalog;
  final HomeCity? current, located;
  final HomeCityHistory history;
  @override
  State<HomeCityPage> createState() => _HomeCityPageState();
}

class _HomeCityPageState extends State<HomeCityPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<String> _history = [];
  late bool _international = widget.current?.international ?? false;
  bool _expanded = false;
  String _query = '';
  late List<HomeCity> _results = widget.catalog.search('', _international);
  @override
  void initState() {
    super.initState();
    widget.history.read().then((codes) {
      if (mounted) setState(() => _history = codes);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _select(HomeCity city) {
    widget.history.remember(city.code);
    Navigator.pop(context, city);
  }

  void _filter() {
    setState(() => _results = widget.catalog.search(_query, _international));
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Widget _chips(List<HomeCity> cities) => LayoutBuilder(
    builder: (context, box) => Wrap(
      spacing: 8,
      runSpacing: 10,
      children: [
        for (final city in cities)
          SizedBox(
            width: (box.maxWidth - 24) / 4,
            child: Material(
              color: const Color(0xFF252525),
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () => _select(city),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 11,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (city.code == widget.located?.code)
                        const Padding(
                          padding: EdgeInsets.only(right: 3),
                          child: Icon(
                            Icons.location_on,
                            size: 15,
                            color: Color(0xFFC9B69E),
                          ),
                        ),
                      Flexible(
                        child: Text(
                          city.shortName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget _section(String title, Widget child, {Widget? trailing}) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    color: const Color(0xFF191919),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xFF999999), fontSize: 14),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final recent = [
      ?widget.located,
      for (final code in _history)
        if (widget.catalog.byCode[code] case final c?)
          if (widget.catalog.selectable(c))
            if (code != widget.located?.code) c,
    ].where((c) => c.international == _international).take(8).toList();
    final related = widget.current == null
        ? <HomeCity>[]
        : widget.catalog.related(widget.current!);
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 6, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: homeCopy(context, '关闭', 'Close', '關閉', 'ปิด'),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  Expanded(
                    child: LegacyConversationSearch(
                      inputKey: const ValueKey('home-city-input'),
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      fillColor: const Color(0xFF252525),
                      controller: _input,
                      maxLength: 100,
                      hint: homeCopy(
                        context,
                        '搜索城市',
                        'Search cities',
                        '搜尋城市',
                        'ค้นหาเมือง',
                      ),
                      onClear: () {
                        _input.clear();
                        _query = '';
                        _filter();
                      },
                      onChanged: (v) {
                        _query = v.trim();
                        _filter();
                      },
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                for (final international in [false, true])
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        _international = international;
                        _filter();
                      },
                      child: Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              width: 3,
                              color: _international == international
                                  ? const Color(0xFFC9B69E)
                                  : Colors.transparent,
                            ),
                          ),
                        ),
                        child: Text(
                          international
                              ? homeCopy(
                                  context,
                                  '国际/港澳台',
                                  'International / HK, MO, TW',
                                  '國際/港澳台',
                                  'ต่างประเทศ / ฮ่องกง มาเก๊า ไต้หวัน',
                                )
                              : homeCopy(
                                  context,
                                  '境内',
                                  'Mainland',
                                  '境內',
                                  'จีนแผ่นดินใหญ่',
                                ),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: _international == international
                                ? Colors.white
                                : const Color(0xFF888888),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                slivers: [
                  if (_query.isEmpty) ...[
                    if (recent.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _section(
                          homeCopy(
                            context,
                            '当前定位/历史访问',
                            'Location / history',
                            '當前定位/歷史訪問',
                            'ตำแหน่ง / ประวัติ',
                          ),
                          _chips(recent),
                        ),
                      ),
                    if (related.isNotEmpty &&
                        widget.current!.international == _international)
                      SliverToBoxAdapter(
                        child: _section(
                          homeCopy(
                            context,
                            '同省城市',
                            'Cities in the same province',
                            '同省城市',
                            'เมืองในจังหวัดเดียวกัน',
                          ),
                          _chips(
                            _expanded ? related : related.take(4).toList(),
                          ),
                          trailing: TextButton(
                            onPressed: () =>
                                setState(() => _expanded = !_expanded),
                            child: Text(
                              homeCopy(
                                context,
                                _expanded ? '收起' : '展开',
                                _expanded ? 'Collapse' : 'Expand',
                                _expanded ? '收起' : '展開',
                                _expanded ? 'ย่อ' : 'ขยาย',
                              ),
                            ),
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: _section(
                        homeCopy(
                          context,
                          '热门城市',
                          'Popular cities',
                          '熱門城市',
                          'เมืองยอดนิยม',
                        ),
                        _chips(widget.catalog.popular(_international)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          homeCopy(
                            context,
                            '全部城市',
                            'All cities',
                            '全部城市',
                            'เมืองทั้งหมด',
                          ),
                          style: const TextStyle(color: Color(0xFF999999)),
                        ),
                      ),
                    ),
                  ],
                  if (_results.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(
                          homeCopy(
                            context,
                            '没有找到城市',
                            'No cities found',
                            '未找到城市',
                            'ไม่พบเมือง',
                          ),
                        ),
                      ),
                    ),
                  SliverList.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final city = _results[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_query.isEmpty &&
                              (i == 0 || city.letter != _results[i - 1].letter))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
                              child: Text(
                                city.letter,
                                style: const TextStyle(
                                  color: Color(0xFFC9B69E),
                                ),
                              ),
                            ),
                          ListTile(
                            key: ValueKey('home-city-${city.code}'),
                            title: Text(
                              city.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: city.country == null
                                ? null
                                : Text(city.country!),
                            onTap: () => _select(city),
                          ),
                        ],
                      );
                    },
                  ),
                  if (_international)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'City data: GeoNames · CC BY 4.0',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
