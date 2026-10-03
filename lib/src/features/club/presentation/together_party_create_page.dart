import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/together_party_draft.dart';
import '../data/together_rule_summary.dart';
import '../data/together_play.dart';
import '../data/together_store.dart';
import '../data/secure_together_publication.dart';
import 'together_publish_confirmation_page.dart';
import 'legacy_club_components.dart';

class TogetherPartyCreatePage extends StatefulWidget {
  const TogetherPartyCreatePage({
    super.key,
    required this.cityCode,
    required this.cityName,
    required this.onBack,
    this.loadLibrary,
    required this.uploadArtwork,
    this.onReview,
    this.publication,
    required this.stores,
    this.loadPackages,
  }) : assert(onReview != null || publication != null),
       assert(loadLibrary != null || publication != null);
  final String cityCode, cityName;
  final TogetherStoreRepository stores;
  final Future<List<TogetherPackage>> Function(String storeRef)? loadPackages;
  final VoidCallback onBack;
  final Future<List<TogetherArtwork>> Function()? loadLibrary;
  final Future<TogetherArtwork?> Function() uploadArtwork;

  /// Opens the authoritative deposit quote/terms confirmation. Not publication.
  final Future<void> Function(TogetherPartyDraft)? onReview;
  final SecureTogetherPublication? publication;
  @override
  State<TogetherPartyCreatePage> createState() =>
      _TogetherPartyCreatePageState();
}

class _TogetherPartyCreatePageState extends State<TogetherPartyCreatePage> {
  Future<List<TogetherPackage>> Function(String)? get _loadPackages =>
      widget.loadPackages ?? widget.publication?.packages;
  final _theme = TextEditingController(),
      _place = TextEditingController(),
      _description = TextEditingController(),
      _capacity = TextEditingController(text: '6'),
      _price = TextEditingController(),
      _total = TextEditingController();
  bool _official = false;
  bool _allowCoins = false;
  TogetherFeeMode _fee = TogetherFeeMode.aa;
  bool _genderRatio = false;
  bool _allowOverage = false;
  final _maleScore = TextEditingController(),
      _femaleScore = TextEditingController();
  final Set<String> _excludedSigns = {};
  final _minimumAge = TextEditingController(),
      _maximumAge = TextEditingController(),
      _overagePrice = TextEditingController(text: '10');
  final _maleSeats = TextEditingController(text: '3'),
      _femaleSeats = TextEditingController(text: '3');
  bool get _usesGenderPricing => _genderRatio || _fee == TogetherFeeMode.menPay;
  DateTime? _start, _end;
  TogetherArtwork? _background;
  final List<TogetherArtwork> _posters = [];
  TogetherArtwork? get _poster => _posters.firstOrNull;
  bool _busy = false;
  String? _error;
  TogetherStore? _store;
  TogetherPackage? _package;
  TogetherTable? _table;

  @override
  void didUpdateWidget(covariant TogetherPartyCreatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cityCode != widget.cityCode ||
        oldWidget.stores != widget.stores) {
      _store = null;
      _package = null;
      _table = null;
      _place.clear();
    }
  }

  Future<void> _pickVenue({bool table = false}) async {
    if (_busy || (table && _store == null)) return;
    final city = widget.cityCode;
    final repository = widget.stores;
    final store = _store;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final entries = table
          ? (await repository.tables(storeRef: store!.ref))
                .where((v) => v.storeRef == store.ref && v.maximumSeats >= 2)
                .toList()
          : (await repository.list(cityCode: city))
                .where((v) => v.cityCode == city && v.ref.isNotEmpty)
                .toList();
      if (!mounted || city != widget.cityCode || repository != widget.stores) {
        return;
      }
      final selected = await showModalBottomSheet<Object>(
        context: context,
        backgroundColor: const Color(0xFF191919),
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    table ? '该门店暂无可用桌台' : '当前城市暂无可选门店',
                    style: const TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    final title = entry is TogetherStore
                        ? entry.name
                        : (entry as TogetherTable).name;
                    final subtitle = entry is TogetherStore
                        ? entry.address
                        : '最多 ${(entry as TogetherTable).maximumSeats} 人';
                    return ListTile(
                      title: Text(
                        title,
                        style: const TextStyle(color: legacyGold),
                      ),
                      subtitle: Text(
                        subtitle,
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () => Navigator.pop(sheetContext, entry),
                    );
                  },
                ),
        ),
      );
      if (!mounted || city != widget.cityCode || repository != widget.stores) {
        return;
      }
      setState(() {
        if (selected is TogetherStore) {
          _store = selected;
          _package = null;
          _table = null;
          _place.text = selected.address;
        } else if (selected is TogetherTable &&
            selected.storeRef == _store?.ref) {
          _table = selected;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取门店或桌台，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _theme,
      _place,
      _description,
      _capacity,
      _price,
      _total,
      _maleSeats,
      _femaleSeats,
      _minimumAge,
      _maximumAge,
      _overagePrice,
      _maleScore,
      _femaleScore,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickTime(bool start) async {
    final now = DateTime.now();
    final initial = (start ? _start : _end) ?? _start ?? now;
    final date = await showDatePicker(
      context: context,
      firstDate: DateUtils.dateOnly(now),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _pickArtwork(bool poster, {bool upload = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      TogetherArtwork? selected;
      if (upload) {
        selected = await widget.uploadArtwork();
      } else {
        final library =
            (await (widget.loadLibrary ?? widget.publication!.artwork)())
                .where((a) => a.status == TogetherArtworkStatus.approved)
                .toList();
        if (!mounted) return;
        selected = await showModalBottomSheet<TogetherArtwork>(
          context: context,
          backgroundColor: const Color(0xFF191919),
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: library.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      '暂无可用样例',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemCount: library.length,
                    itemBuilder: (_, i) => InkWell(
                      onTap: () => Navigator.pop(context, library[i]),
                      child: Column(
                        children: [
                          Expanded(child: CachedMediaImage(library[i].url)),
                          Text(
                            library[i].name,
                            style: const TextStyle(color: legacyGold),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      }
      if (!mounted || selected == null) return;
      setState(() {
        if (poster) {
          if (_posters.any((p) => p.ref == selected!.ref)) {
            _error = '这张海报已选择';
          } else if (_posters.length < 3) {
            _posters.add(selected!);
          }
        } else {
          _background = selected;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取素材，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPackage() async {
    final store = _store;
    if (store == null || _loadPackages == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final packages = await _loadPackages!(store.ref);
      if (!mounted || _store != store) return;
      final selected = await showModalBottomSheet<TogetherPackage>(
        context: context,
        backgroundColor: const Color(0xFF191919),
        builder: (sheet) => SafeArea(
          child: packages.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('该门店暂无组局套餐', style: TextStyle(color: legacyGold)),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in packages.where(
                      (p) => p.storeRef == store.ref,
                    ))
                      ListTile(
                        title: Text(
                          p.name,
                          style: const TextStyle(color: legacyGold),
                        ),
                        subtitle: Text(
                          '¥${(p.baseTotalMinor / 100).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        onTap: () => Navigator.pop(sheet, p),
                      ),
                  ],
                ),
        ),
      );
      if (!mounted || _store != store || selected == null) return;
      setState(() {
        _package = selected;
        _total.text = (selected.baseTotalMinor / 100).toStringAsFixed(2);
      });
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法读取套餐，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() async {
    if (_busy) return;
    if (_store == null) {
      setState(() => _error = '请先选择活动门店');
      return;
    }
    final count = int.tryParse(_capacity.text.trim());
    final price =
        _fee == TogetherFeeMode.hostTreat || _fee == TogetherFeeMode.menPay
        ? 0
        : TogetherPartyDraft.parseMoney(_price.text);
    final total = TogetherPartyDraft.parseMoney(_total.text);
    if (_loadPackages != null && _package == null) {
      setState(() => _error = '请选择门店组局套餐');
      return;
    }
    if (count == null ||
        price == null ||
        total == null ||
        _start == null ||
        _end == null ||
        _background == null ||
        _poster == null) {
      setState(() => _error = '请完整填写时间、人数、费用，并选择背景和海报');
      return;
    }
    final minimumAge = int.tryParse(_minimumAge.text.trim());
    final maximumAge = int.tryParse(_maximumAge.text.trim());
    final overagePrice = TogetherPartyDraft.parseMoney(_overagePrice.text);
    final allowOverage = _allowOverage && _fee != TogetherFeeMode.hostTreat;
    if ((_minimumAge.text.isNotEmpty &&
            (minimumAge == null || minimumAge < 18 || minimumAge > 120)) ||
        (_maximumAge.text.isNotEmpty &&
            (maximumAge == null || maximumAge < 18 || maximumAge > 120)) ||
        (minimumAge != null && maximumAge != null && minimumAge > maximumAge) ||
        (allowOverage && (maximumAge == null || overagePrice == null))) {
      setState(() => _error = '请检查年龄范围；超龄加价需要设置年龄上限和每岁金额');
      return;
    }
    final maleScore = double.tryParse(_maleScore.text.trim());
    final femaleScore = double.tryParse(_femaleScore.text.trim());
    if ((_maleScore.text.trim().isNotEmpty &&
            (maleScore == null ||
                !maleScore.isFinite ||
                maleScore < 0 ||
                maleScore > 100)) ||
        (_femaleScore.text.trim().isNotEmpty &&
            (femaleScore == null ||
                !femaleScore.isFinite ||
                femaleScore < 0 ||
                femaleScore > 100))) {
      setState(() => _error = '男女颜值评分须为0至100分，不限制可留空');
      return;
    }
    final draft = TogetherPartyDraft(
      official: _official,
      allowCoins: _allowCoins,
      theme: _theme.text.trim(),
      cityCode: widget.cityCode,
      store: _store!,
      place: _place.text.trim(),
      startsAt: _start!,
      endsAt: _end!,
      capacity: count,
      feeMode: _fee,
      priceMinor: price,
      totalCostMinor: total,
      description: _description.text.trim(),
      background: _background!,
      poster: _poster!,
      additionalPosters: _posters.skip(1).toList(),
      table: _table,
      package: _package,
      eligibilityRules: {
        'minAge': ?minimumAge,
        'maxAge': ?maximumAge,
        'minimumMaleScore': ?maleScore,
        'minimumFemaleScore': ?femaleScore,
        if (_excludedSigns.isNotEmpty)
          'excludedStarSigns': _excludedSigns.toList(),
        if (allowOverage) 'overageCentsPerYear': '$overagePrice',
      },
      maleSeats: _usesGenderPricing
          ? int.tryParse(_maleSeats.text.trim())
          : null,
      femaleSeats: _usesGenderPricing
          ? int.tryParse(_femaleSeats.text.trim())
          : null,
      femaleBasePriceMinor: _usesGenderPricing ? price : null,
    );
    final error = draft.validate(now: DateTime.now());
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final publication = widget.publication;
      if (publication != null) {
        final partyRef = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => TogetherPublishConfirmationPage(
              draft: draft,
              publication: publication,
            ),
          ),
        );
        if (mounted && partyRef != null) Navigator.of(context).pop(partyRef);
      } else {
        await widget.onReview!(draft);
      }
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法获取确认信息，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool number = false,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: legacyGold),
        filled: true,
        fillColor: const Color(0xFF202020),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
  Widget _artwork(bool poster) {
    final asset = poster ? _poster : _background;
    final title = poster ? '活动海报' : '卡片背景';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: legacyGold)),
        if (poster && _posters.isNotEmpty)
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < _posters.length; i++)
                InputChip(
                  label: Text('海报${i + 1} · ${_posters[i].name}'),
                  onDeleted: _busy
                      ? null
                      : () => setState(() => _posters.removeAt(i)),
                ),
            ],
          ),
        if (asset != null) ...[
          const SizedBox(height: 8),
          SizedBox(height: 90, child: CachedMediaImage(asset.url)),
          Text(switch (asset.status) {
            TogetherArtworkStatus.approved => '审核通过',
            TogetherArtworkStatus.pending => '审核中，通过后可发布',
            TogetherArtworkStatus.rejected =>
              asset.rejectionReason ?? '审核未通过，请重新选择',
          }, style: const TextStyle(color: Colors.white54)),
        ],
        Row(
          children: [
            TextButton(
              onPressed: _busy || (poster && _posters.length == 3)
                  ? null
                  : () => _pickArtwork(poster),
              child: const Text('样例库'),
            ),
            TextButton(
              onPressed: _busy || (poster && _posters.length == 3)
                  ? null
                  : () => _pickArtwork(poster, upload: true),
              child: const Text('自行上传'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: '发起组局',
    onBack: widget.onBack,
    showMockLabel: false,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Text(
          widget.cityName,
          style: const TextStyle(color: legacyGold, fontSize: 17),
        ),
        const SizedBox(height: 18),
        _field('派对主题', _theme),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            _store?.name ?? '选择活动门店',
            style: const TextStyle(color: legacyGold),
          ),
          trailing: const Icon(Icons.chevron_right, color: legacyGold),
          onTap: _busy ? null : () => _pickVenue(),
        ),
        if (_store != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _table?.name ?? '选择卡座 / 桌台（可选）',
              style: const TextStyle(color: legacyGold),
            ),
            trailing: _table == null
                ? const Icon(Icons.chevron_right, color: legacyGold)
                : IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _table = null),
                    icon: const Icon(Icons.close, color: legacyGold),
                  ),
            onTap: _busy ? null : () => _pickVenue(table: true),
          ),
        _field('活动地点', _place),
        for (final start in [true, false])
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              start ? '开始时间' : '结束时间',
              style: const TextStyle(color: legacyGold),
            ),
            subtitle: Text(
              ((start ? _start : _end)?.toString().substring(0, 16)) ??
                  '请选择日期和时间',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: const Icon(Icons.chevron_right, color: legacyGold),
            onTap: () => _pickTime(start),
          ),
        const SizedBox(height: 16),
        _field(
          '总人数${_table == null ? '' : '（最多${_table!.maximumSeats}人）'}',
          _capacity,
          number: true,
        ),
        SwitchListTile(
          title: const Text('门店官方发起', style: TextStyle(color: legacyGold)),
          subtitle: const Text(
            '仅本店官方账号所属商家可用，服务器核验后免押金',
            style: TextStyle(color: legacyGold),
          ),
          value: _official,
          onChanged: _busy ? null : (v) => setState(() => _official = v),
        ),
        SwitchListTile(
          title: const Text('允许金币抵扣', style: TextStyle(color: legacyGold)),
          subtitle: const Text(
            '10金币抵1元，由平台补贴给门店',
            style: TextStyle(color: legacyGold),
          ),
          value: _allowCoins,
          onChanged: _busy ? null : (v) => setState(() => _allowCoins = v),
        ),
        DropdownButtonFormField<TogetherFeeMode>(
          initialValue: _fee,
          dropdownColor: const Color(0xFF202020),
          style: const TextStyle(color: legacyGold),
          items: const [
            DropdownMenuItem(value: TogetherFeeMode.aa, child: Text('AA 制')),
            DropdownMenuItem(
              value: TogetherFeeMode.menPay,
              child: Text('男 A 女免'),
            ),
            DropdownMenuItem(
              value: TogetherFeeMode.hostTreat,
              child: Text('发起者请客 · 全免'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _fee = value);
          },
        ),
        const SizedBox(height: 18),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('设置男女比例', style: TextStyle(color: legacyGold)),
          value: _usesGenderPricing,
          onChanged: _fee == TogetherFeeMode.menPay
              ? null
              : (value) => setState(() => _genderRatio = value ?? false),
        ),
        if (_usesGenderPricing) ...[
          _field('计划男士人数', _maleSeats, number: true),
          _field('计划女士人数', _femaleSeats, number: true),
          const Text(
            '男女人数合计须等于总人数。按套餐基础消费计算男士分摊金额。',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 12),
        ],
        if (_fee == TogetherFeeMode.aa)
          _field(
            _usesGenderPricing ? '女士基础分摊金额（元）' : '每人费用（元）',
            _price,
            number: true,
          ),
        if (_loadPackages == null)
          _field('整场费用（元）', _total, number: true)
        else
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _package?.name ?? '选择门店组局套餐',
              style: const TextStyle(color: legacyGold),
            ),
            subtitle: _package == null
                ? null
                : Text(
                    '基础消费 ¥${(_package!.baseTotalMinor / 100).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
            onTap: _busy || _store == null ? null : _pickPackage,
          ),
        Text(
          _official
              ? '本店官方活动经服务器核验商家身份后，无需冻结押金。'
              : '个人发起按商家基础消费冻结 APP 余额。参加者付款并入场核销后，等额押金立即解冻回 APP 可用余额。',
          style: const TextStyle(color: Colors.white54, height: 1.5),
        ),
        const SizedBox(height: 18),
        _field('最低年龄（可不填，按活动当天周岁）', _minimumAge, number: true),
        _field('最高年龄（可不填）', _maximumAge, number: true),
        if (_fee != TogetherFeeMode.hostTreat) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('允许超龄加价参加', style: TextStyle(color: legacyGold)),
            value: _allowOverage,
            onChanged: (value) =>
                setState(() => _allowOverage = value ?? false),
          ),
          if (_allowOverage) _field('每超一岁加收（元）', _overagePrice, number: true),
        ],
        ExpansionTile(
          title: const Text('颜值与星座要求', style: TextStyle(color: legacyGold)),
          subtitle: const Text(
            '可选，不设置则不限制',
            style: TextStyle(color: Colors.white54),
          ),
          children: [
            _field('男士最低颜值评分（0—100）', _maleScore, number: true),
            _field('女士最低颜值评分（0—100）', _femaleScore, number: true),
            const Text('不接受的星座（可多选）', style: TextStyle(color: legacyGold)),
            Wrap(
              spacing: 8,
              children: [
                for (final sign in togetherStarSigns)
                  FilterChip(
                    label: Text(sign),
                    selected: _excludedSigns.contains(sign),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _excludedSigns.add(sign);
                            } else {
                              _excludedSigns.remove(sign);
                            }
                          }),
                  ),
              ],
            ),
          ],
        ),
        _field('活动介绍与包含内容', _description, lines: 4),
        _artwork(false),
        const SizedBox(height: 14),
        _artwork(true),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_error!, style: const TextStyle(color: legacyPink)),
          ),
        FilledButton(
          onPressed: _busy ? null : _review,
          style: FilledButton.styleFrom(
            backgroundColor: legacyGold,
            foregroundColor: Colors.black,
          ),
          child: Text(_busy ? '请稍候' : '下一步 · 确认押金与规则'),
        ),
      ],
    ),
  );
}
