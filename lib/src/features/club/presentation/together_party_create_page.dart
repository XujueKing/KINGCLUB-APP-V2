import 'package:flutter/material.dart';

import '../../../core/media/cached_media_image.dart';
import '../data/together_party_draft.dart';
import '../data/together_play.dart';
import '../data/together_store.dart';
import 'legacy_club_components.dart';

class TogetherPartyCreatePage extends StatefulWidget {
  const TogetherPartyCreatePage({
    super.key,
    required this.cityCode,
    required this.cityName,
    required this.onBack,
    required this.loadLibrary,
    required this.uploadArtwork,
    required this.onReview,
    required this.stores,
  });
  final String cityCode, cityName;
  final TogetherStoreRepository stores;
  final VoidCallback onBack;
  final Future<List<TogetherArtwork>> Function() loadLibrary;
  final Future<TogetherArtwork?> Function() uploadArtwork;

  /// Opens the authoritative deposit quote/terms confirmation. Not publication.
  final Future<void> Function(TogetherPartyDraft) onReview;
  @override
  State<TogetherPartyCreatePage> createState() =>
      _TogetherPartyCreatePageState();
}

class _TogetherPartyCreatePageState extends State<TogetherPartyCreatePage> {
  final _theme = TextEditingController(),
      _place = TextEditingController(),
      _description = TextEditingController(),
      _capacity = TextEditingController(text: '6'),
      _price = TextEditingController(),
      _total = TextEditingController();
  TogetherFeeMode _fee = TogetherFeeMode.aa;
  DateTime? _start, _end;
  TogetherArtwork? _background, _poster;
  bool _busy = false;
  String? _error;
  TogetherStore? _store;
  TogetherTable? _table;

  @override
  void didUpdateWidget(covariant TogetherPartyCreatePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cityCode != widget.cityCode ||
        oldWidget.stores != widget.stores) {
      _store = null;
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
        final library = (await widget.loadLibrary())
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
          _poster = selected;
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

  Future<void> _review() async {
    if (_busy) return;
    if (_store == null) {
      setState(() => _error = '请先选择活动门店');
      return;
    }
    final count = int.tryParse(_capacity.text.trim());
    final price = _fee == TogetherFeeMode.hostTreat
        ? 0
        : TogetherPartyDraft.parseMoney(_price.text);
    final total = TogetherPartyDraft.parseMoney(_total.text);
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
    final draft = TogetherPartyDraft(
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
      table: _table,
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
      await widget.onReview(draft);
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
              onPressed: _busy ? null : () => _pickArtwork(poster),
              child: const Text('样例库'),
            ),
            TextButton(
              onPressed: _busy
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
        if (_fee != TogetherFeeMode.hostTreat)
          _field(
            _fee == TogetherFeeMode.menPay ? '每位男士费用（元）' : '每人费用（元）',
            _price,
            number: true,
          ),
        _field('整场费用（元）', _total, number: true),
        const Text(
          '从 APP 余额冻结整场押金。参加者付款给商家后，等额押金解冻回 APP 可用余额。',
          style: TextStyle(color: Colors.white54, height: 1.5),
        ),
        const SizedBox(height: 18),
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
