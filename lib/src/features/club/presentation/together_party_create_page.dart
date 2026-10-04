import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import '../../../core/media/cached_media_image.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/together_party_draft.dart';
import '../data/together_rule_summary.dart';
import '../data/together_play.dart';
import '../data/together_store.dart';
import '../data/secure_together_publication.dart';
import 'together_publish_confirmation_page.dart';
import 'together_store_picker_page.dart';
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
    this.personal = false,
    this.onSelectCity,
  }) : assert(onReview != null || publication != null),
       assert(loadLibrary != null || publication != null);
  final String cityCode, cityName;
  final bool personal;
  final VoidCallback? onSelectCity;
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
  final _welcome = TextEditingController();
  int _step = 0;
  String? _plan;
  bool _allowCoins = false;
  int? _minimumExperience;
  TogetherFeeMode _fee = TogetherFeeMode.aa;
  bool _genderRatio = false;
  bool _allowOverage = false;
  final _maleScore = TextEditingController(),
      _femaleScore = TextEditingController();
  final Set<String> _excludedSigns = {};
  final Set<String> _excludedAnimals = {};
  final _minimumAge = TextEditingController(),
      _maximumAge = TextEditingController(),
      _overagePrice = TextEditingController(text: '10');
  final _maleSeats = TextEditingController(text: '3'),
      _femaleSeats = TextEditingController(text: '3');
  bool get _usesGenderPricing =>
      _fee != TogetherFeeMode.hostTreat &&
      (_genderRatio || _fee == TogetherFeeMode.menPay);
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
      _total.clear();
      _step = 0;
    }
  }

  Future<void> _pickVenue({bool table = false}) async {
    if (_busy || (table && _store == null)) return;
    if (widget.personal && !table) {
      final city = widget.cityCode;
      final selected = await TogetherStorePickerPage.open(
        context,
        repository: widget.stores,
        cityCode: city,
        cityName: widget.cityName,
      );
      if (!mounted ||
          city != widget.cityCode ||
          selected == null ||
          selected.ref == _store?.ref) {
        return;
      }
      setState(() {
        _store = selected;
        _table = null;
        _package = null;
        _total.clear();
        _place.text = selected.address;
        _error = null;
      });
      return;
    }
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
          if (widget.personal) {
            final count = int.tryParse(_capacity.text) ?? 2;
            _capacity.text = '${count.clamp(2, selected.maximumSeats)}';
          }
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
    _welcome.dispose();
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
        if (widget.publication?.memberLevels.containsKey(_minimumExperience) !=
            true) {
          _minimumExperience = null;
        }
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
    if (widget.personal && _table == null) {
      setState(() => _error = '请先选择卡座');
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
      official: widget.personal ? false : _official,
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
      description: [
        if (widget.personal) _welcome.text.trim(),
        _description.text.trim(),
      ].where((text) => text.isNotEmpty).join('\n\n'),
      background: _background!,
      poster: _poster!,
      additionalPosters: _posters.skip(1).toList(),
      table: _table,
      package: _package,
      eligibilityRules: {
        'minAge': ?minimumAge,
        'maxAge': ?maximumAge,
        'minimumMaleScore': ?maleScore,
        'minimumExperience': ?_minimumExperience,
        'minimumFemaleScore': ?femaleScore,
        if (_excludedSigns.isNotEmpty)
          'excludedStarSigns': _excludedSigns.toList(),
        if (_excludedAnimals.isNotEmpty)
          'excludedChineseZodiacs': _excludedAnimals.toList(),
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

  Widget _group(List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: const BoxDecoration(
      color: Color(0xFF11100D),
      border: Border.symmetric(
        horizontal: BorderSide(color: Color(0x22C9B69E)),
      ),
    ),
    child: Column(children: children),
  );

  Widget _selection(
    String label,
    String value,
    VoidCallback? action, {
    bool accent = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 6),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: legacyGold, fontSize: 16),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : action,
                style: TextButton.styleFrom(
                  backgroundColor: action == null || accent
                      ? Colors.transparent
                      : const Color(0x15C9B69E),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: accent ? const Color(0xFFFCA800) : legacyGold,
                          fontSize: 16,
                          fontWeight: accent
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (action != null && !accent) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 16,
                        color: legacyGold,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _toggle(
    String title,
    String hint,
    bool value,
    ValueChanged<bool> change,
  ) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: title,
                  style: const TextStyle(color: legacyGold, fontSize: 16),
                ),
                TextSpan(
                  text: '（$hint）',
                  style: const TextStyle(
                    color: Color(0xFF77716A),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        CupertinoSwitch(
          value: value,
          activeTrackColor: const Color(0xFF9C8B76),
          onChanged: _busy ? null : (v) => setState(() => change(v)),
        ),
      ],
    ),
  );

  Future<void> _wheel(
    String title,
    List<List<String>> columns,
    List<int> initial,
    void Function(List<int>) apply,
  ) async {
    final chosen = [...initial];
    final controllers = [
      for (final i in initial) FixedExtentScrollController(initialItem: i),
    ];
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF191714),
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: 310,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  title,
                  style: const TextStyle(color: legacyGold, fontSize: 18),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < columns.length; c++)
                      Expanded(
                        child: CupertinoPicker(
                          scrollController: controllers[c],
                          itemExtent: 42,
                          onSelectedItemChanged: (i) => chosen[c] = i,
                          children: [
                            for (final value in columns[c])
                              Center(
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    color: legacyGold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheet, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(sheet, true),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
    if (result == true && mounted) setState(() => apply(chosen));
  }

  Future<void> _pickLimits(bool age) async {
    final left = age ? _minimumAge : _maleScore;
    final right = age ? _maximumAge : _femaleScore;
    final values = [
      '',
      for (var i = age ? 18 : 0; i <= (age ? 120 : 100); i++) '$i',
    ];
    await _wheel(
      age ? '年龄范围 · 按活动当天周岁' : 'AI卡颜 · 男 / 女最低分',
      [
        for (var c = 0; c < 2; c++)
          [for (final v in values) v.isEmpty ? '不限制' : '$v${age ? '岁' : '分'}'],
      ],
      [
        values.indexOf(left.text).clamp(0, values.length - 1),
        values.indexOf(right.text).clamp(0, values.length - 1),
      ],
      (indexes) {
        left.text = values[indexes[0]];
        right.text = values[indexes[1]];
      },
    );
  }

  String _limitText(bool age) {
    final a = age ? _minimumAge.text : _maleScore.text;
    final b = age ? _maximumAge.text : _femaleScore.text;
    if (a.isEmpty && b.isEmpty) return '不限制';
    return age
        ? '${a.isEmpty ? '不限' : a} — ${b.isEmpty ? '不限' : b} 岁'
        : '男 ${a.isEmpty ? '不限' : a} / 女 ${b.isEmpty ? '不限' : b}';
  }

  static const _steps = ['选择门店与方案', '预订卡座与套餐', '设置参加规则', '完善活动介绍'];

  void _previous() {
    if (_step == 0) {
      widget.onBack();
      return;
    }
    setState(() {
      _step--;
      _error = null;
    });
  }

  void _next() {
    String? error;
    if (_step == 0) {
      if (_store == null) {
        error = '请选择允许组局的商家';
      } else if (_plan == null) {
        error = '请选择组局方案或自定义';
      } else if (_theme.text.trim().isEmpty) {
        error = '请输入活动主题';
      } else if (_theme.text.trim().length > 30) {
        error = '活动主题请控制在30字以内';
      } else if (_welcome.text.trim().isEmpty) {
        error = '请输入欢迎语';
      } else if (_welcome.text.trim().length > 500) {
        error = '欢迎语请控制在500字以内';
      }
    } else if (_step == 1) {
      if (_start == null || _end == null) {
        error = '请选择活动开始和结束时间';
      } else if (!_end!.isAfter(_start!)) {
        error = '结束时间需晚于开始时间';
      } else if (!_start!.isAfter(DateTime.now())) {
        error = '活动开始时间需晚于当前时间';
      } else if (_table == null) {
        error = '请选择卡座';
      } else if (_package == null) {
        error = '请选择活动套餐';
      }
    } else if (_step == 2) {
      final count = int.tryParse(_capacity.text);
      final male = int.tryParse(_maleSeats.text);
      final female = int.tryParse(_femaleSeats.text);
      final price = TogetherPartyDraft.parseMoney(_price.text);
      final minAge = int.tryParse(_minimumAge.text);
      final maxAge = int.tryParse(_maximumAge.text);
      if (_fee == TogetherFeeMode.aa && price == null) {
        error = '请输入精确到分的每人金额';
      } else if (_usesGenderPricing &&
          (male == null ||
              female == null ||
              male <= 0 ||
              female < 0 ||
              male + female != count)) {
        error = '男女人数合计必须等于总人数，男士至少1人';
      } else if (minAge != null && maxAge != null && minAge > maxAge) {
        error = '年龄下限不能超过上限';
      }
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_step == 3) {
      _review();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _step++;
      _error = null;
    });
  }

  Widget _planOption(
    String title,
    String description,
    TogetherFeeMode mode,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
    child: Material(
      color: _plan == title ? const Color(0xFF302A22) : const Color(0xFF191816),
      borderRadius: BorderRadius.circular(10),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: legacyGold,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
        ),
        trailing: Icon(
          _plan == title ? Icons.radio_button_checked : Icons.radio_button_off,
          color: _plan == title ? legacyGold : Colors.white38,
        ),
        onTap: () => setState(() {
          _plan = title;
          _fee = mode;
          _error = null;
        }),
      ),
    ),
  );

  Widget _personalPage() => PopScope(
    canPop: _step == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _previous();
    },
    child: LegacyClubScaffold(
      title: '组局玩',
      onBack: _previous,
      showMockLabel: false,
      titleColor: Colors.white,
      titleFontSize: 17,
      titleFontWeight: FontWeight.w600,
      headerHeight: 56,
      child: ColoredBox(
        color: Colors.black,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _steps[_step],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${_step + 1} / 4',
                        style: const TextStyle(color: legacyGold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: List.generate(
                      4,
                      (i) => Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                          color: i <= _step ? legacyGold : Colors.white12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                key: ValueKey('personal-party-step-$_step'),
                padding: EdgeInsets.zero,
                children: [
                  if (_step == 0) ...[
                    _group([
                      _selection('所在城市', widget.cityName, widget.onSelectCity),
                      _selection(
                        '选择门店：',
                        _store?.name ?? '${widget.cityName} · 请选择',
                        () => _pickVenue(),
                      ),
                    ]),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 12, 24, 14),
                      child: Text(
                        '选择组局方案',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _planOption('AA组局', '按套餐消费分摊，可调整男女收费', TogetherFeeMode.aa),
                    _planOption('男A女免', '男士分摊，女士免费参加', TogetherFeeMode.menPay),
                    _planOption(
                      '我请客',
                      '由我承担套餐消费，邀请朋友参加',
                      TogetherFeeMode.hostTreat,
                    ),
                    _planOption('自定义', '自行设置人数、收费和参加规则', TogetherFeeMode.aa),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _field('活动主题', _theme),
                          _field('欢迎语', _welcome, lines: 2),
                        ],
                      ),
                    ),
                  ],
                  if (_step == 1)
                    _group([
                      _selection(
                        '预订时间：',
                        _start == null
                            ? '选择日期时间'
                            : _start.toString().substring(0, 16),
                        () => _pickTime(true),
                        accent: true,
                      ),
                      _selection(
                        '结束时间：',
                        _end == null
                            ? '选择日期时间'
                            : _end.toString().substring(0, 16),
                        () => _pickTime(false),
                        accent: true,
                      ),
                      _selection(
                        '选择卡座：',
                        _table?.name ?? '请选择',
                        _store == null ? null : () => _pickVenue(table: true),
                      ),
                      _selection(
                        '聚会人数：',
                        '${_capacity.text} 人',
                        _table == null
                            ? null
                            : () {
                                final max = _table!.maximumSeats;
                                _wheel(
                                  '聚会人数 · 最多 $max 人',
                                  [
                                    [for (var i = 2; i <= max; i++) '$i 人'],
                                  ],
                                  [
                                    ((int.tryParse(_capacity.text) ?? 2) - 2)
                                        .clamp(0, max - 2),
                                  ],
                                  (v) => _capacity.text = '${v[0] + 2}',
                                );
                              },
                      ),
                      _selection(
                        '选套餐：',
                        _package?.name ?? '请选择',
                        _store == null ? null : _pickPackage,
                      ),
                      _selection(
                        '套餐价格：',
                        _package == null
                            ? '—'
                            : '¥${(_package!.baseTotalMinor / 100).toStringAsFixed(2)} 元',
                        null,
                        accent: true,
                      ),
                    ]),
                  if (_step == 2)
                    _group([
                      _selection(
                        'AI卡颜：',
                        _limitText(false),
                        () => _pickLimits(false),
                      ),
                      _selection(
                        '年龄限制：',
                        _limitText(true),
                        () => _pickLimits(true),
                      ),
                    ]),
                  if (_step == 2)
                    _group([
                      _selection(
                        '费用方式：',
                        switch (_fee) {
                          TogetherFeeMode.aa => 'AA制',
                          TogetherFeeMode.menPay => '男A女免',
                          TogetherFeeMode.hostTreat => '我请客',
                        },
                        () => _wheel(
                          '费用方式',
                          [
                            ['AA制', '男A女免', '我请客'],
                          ],
                          [
                            [
                              TogetherFeeMode.aa,
                              TogetherFeeMode.menPay,
                              TogetherFeeMode.hostTreat,
                            ].indexOf(_fee),
                          ],
                          (v) => _fee = [
                            TogetherFeeMode.aa,
                            TogetherFeeMode.menPay,
                            TogetherFeeMode.hostTreat,
                          ][v[0]],
                        ),
                      ),
                      if (_fee != TogetherFeeMode.hostTreat) ...[
                        _toggle('设置男女配比', '按人数分摊套餐', _usesGenderPricing, (v) {
                          if (_fee != TogetherFeeMode.menPay) _genderRatio = v;
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              if (_usesGenderPricing) ...[
                                _field('男士人数', _maleSeats, number: true),
                                _field('女士人数', _femaleSeats, number: true),
                              ],
                              if (_fee == TogetherFeeMode.aa)
                                _field(
                                  _usesGenderPricing ? '女士每人金额（元）' : '每人金额（元）',
                                  _price,
                                  number: true,
                                ),
                            ],
                          ),
                        ),
                      ],
                      _toggle(
                        '接受金币',
                        '10金币抵1元',
                        _allowCoins,
                        (v) => _allowCoins = v,
                      ),
                    ]),
                  if (_step == 3)
                    _group([
                      Padding(
                        padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                        child: Column(
                          children: [
                            _field('活动介绍与包含内容', _description, lines: 3),
                            _artwork(false),
                            _artwork(true),
                          ],
                        ),
                      ),
                    ]),
                  if (_step == 3)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(28, 4, 28, 20),
                      child: Text(
                        '押金从APP余额冻结。参加者付款并入场核销后，按实收金额解冻。',
                        style: TextStyle(
                          color: Color(0xFF8B8174),
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 10,
                ),
                child: Text(
                  _error!,
                  key: const ValueKey('personal-party-error'),
                  style: const TextStyle(color: legacyPink),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    TextButton(
                      onPressed: _busy ? null : _previous,
                      child: const Text(
                        '\u4e0a\u4e00\u6b65',
                        style: TextStyle(color: legacyGold),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: legacyGold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(
                        _busy
                            ? '\u8bf7\u7a0d\u5019'
                            : _step == 3
                            ? '\u786e\u8ba4\u65b9\u6848\u4e0e\u62bc\u91d1'
                            : '\u4e0b\u4e00\u6b65',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) =>
      widget.personal ? _personalPage() : _standardPage(context);

  Widget _standardPage(BuildContext context) => LegacyClubScaffold(
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
          title: const Text('颜值、星座与属相要求', style: TextStyle(color: legacyGold)),
          subtitle: const Text(
            '可选，不设置则不限制',
            style: TextStyle(color: Colors.white54),
          ),
          children: [
            _field('男士最低颜值评分（0—100）', _maleScore, number: true),
            _field('女士最低颜值评分（0—100）', _femaleScore, number: true),
            const Text(
              '不接受的属相（按农历春节划分，可多选）',
              style: TextStyle(color: legacyGold),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final animal in togetherChineseZodiacs)
                  FilterChip(
                    label: Text(animal),
                    selected: _excludedAnimals.contains(animal),
                    onSelected: _busy
                        ? null
                        : (selected) => setState(() {
                            if (selected) {
                              _excludedAnimals.add(animal);
                            } else {
                              _excludedAnimals.remove(animal);
                            }
                          }),
                  ),
              ],
            ),
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
        if (widget.publication?.memberLevels.isNotEmpty == true)
          DropdownButtonFormField<int>(
            initialValue: _minimumExperience ?? -1,
            decoration: const InputDecoration(labelText: '最低会员等级'),
            dropdownColor: const Color(0xFF191919),
            style: const TextStyle(color: legacyGold),
            items: [
              const DropdownMenuItem(value: -1, child: Text('不限等级')),
              for (final level in widget.publication!.memberLevels.entries)
                DropdownMenuItem(
                  value: level.key,
                  child: Text('${level.value}及以上'),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) => setState(() {
                    _minimumExperience = value == -1 ? null : value;
                  }),
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
