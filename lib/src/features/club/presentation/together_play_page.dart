import 'package:flutter/material.dart';

import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_date_picker.dart';

String _two(int value) => value.toString().padLeft(2, '0');
String _date(DateTime value) => '${_two(value.month)}.${_two(value.day)}';
String _time(DateTime value) => '${_two(value.hour)}:${_two(value.minute)}';
String togetherTimeRange(TogetherParty party) {
  final sameDay = DateUtils.isSameDay(party.startsAt, party.endsAt);
  return '${_date(party.startsAt)} ${_time(party.startsAt)}–'
      '${sameDay ? '' : '${_date(party.endsAt)} '}${_time(party.endsAt)}';
}

class TogetherPlayPage extends StatefulWidget {
  const TogetherPlayPage({
    super.key,
    required this.repository,
    required this.cityCode,
    required this.cityName,
    required this.onBack,
    required this.onJoin,
    required this.onAdmission,
    required this.onCreate,
    this.today,
    this.reviewOnly = false,
  });
  final TogetherPlayRepository repository;
  final String cityCode, cityName;
  final VoidCallback onBack, onCreate;
  final Future<void> Function(TogetherParty) onJoin, onAdmission;
  final DateTime? today;
  final bool reviewOnly;
  @override
  State<TogetherPlayPage> createState() => _TogetherPlayPageState();
}

class _TogetherPlayPageState extends State<TogetherPlayPage> {
  late final DateTime _today = DateUtils.dateOnly(
    widget.today ?? DateTime.now(),
  );
  late DateTime _selectedDate = _today;
  late final DateTime _lastDate = DateTime(_today.year, _today.month + 6, 0);
  int _generation = 0;
  bool _loading = true;
  String? _error;
  List<TogetherParty> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TogetherPlayPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cityCode != oldWidget.cityCode ||
        widget.repository != oldWidget.repository) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final date = _selectedDate;
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
    });
    try {
      final items = await widget.repository.list(
        cityCode: widget.cityCode,
        date: date,
      );
      if (!mounted || generation != _generation) return;
      setState(
        () => _items = items
            .where(
              (p) =>
                  p.cityCode == widget.cityCode &&
                  DateUtils.isSameDay(p.startsAt, date),
            )
            .toList(),
      );
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '暂时无法加载活动');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(TogetherParty party) async {
    if (widget.reviewOnly) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TogetherPartyDetailPage(
          party: party,
          repository: widget.repository,
          onJoin: widget.onJoin,
          onAdmission: widget.onAdmission,
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: '一起玩',
    titleFontWeight: FontWeight.w400,
    onBack: widget.onBack,
    showMockLabel: false,
    headerAction: TextButton(
      onPressed: widget.onCreate,
      style: TextButton.styleFrom(foregroundColor: legacyGold),
      child: const Text('发起组局', style: TextStyle(fontSize: 13)),
    ),
    child: Column(
      children: [
        TogetherDateStrip(
          firstDate: _today,
          lastDate: _lastDate,
          selectedDate: _selectedDate,
          onSelected: (date) {
            if (!DateUtils.isSameDay(date, _selectedDate)) {
              _selectedDate = date;
              _load();
            }
          },
        ),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: legacyGold),
                )
              : _error != null
              ? Center(
                  child: TextButton(
                    onPressed: _load,
                    child: Text('$_error · 重试'),
                  ),
                )
              : _items.isEmpty
              ? const Center(
                  child: Text(
                    '这一天还没有同城组局',
                    style: TextStyle(color: legacyGold),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, index) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.reviewOnly && index == 0) ...[
                        const Text(
                          '布局样例 · 非真实活动',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                      ],
                      TogetherPartyCard(
                        party: _items[index],
                        onTap: () => _open(_items[index]),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    ),
  );
}

class TogetherPartyCard extends StatelessWidget {
  const TogetherPartyCard({
    super.key,
    required this.party,
    required this.onTap,
  });
  final TogetherParty party;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('together-card-${party.ref}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const RadialGradient(
            center: Alignment.bottomRight,
            radius: 1.6,
            colors: [legacyMagenta, Color(0xFF5A1E80)],
          ),
          image: party.backgroundUrl == null
              ? null
              : DecorationImage(
                  image: NetworkImage(party.backgroundUrl!),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(
                    Color(0x66000000),
                    BlendMode.darken,
                  ),
                ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party.theme,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '${party.merchantHost ? '商家' : '会员'}发起 · ${party.hostName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: legacyPink,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 122,
                    child: TogetherParticipants(party: party),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                togetherTimeRange(party),
                style: togetherLegacyDateStyle(
                  MediaQuery.sizeOf(context).width * 24 / 750,
                  legacyPink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${party.storeName} · ${party.place}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: legacyPink, fontSize: 12),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          party.feeLabel,
                          style: const TextStyle(
                            color: legacyPink,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          party.priceLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (party.actionState == TogetherJoinState.joined)
                    const Icon(
                      Icons.qr_code_2,
                      size: 46,
                      color: Colors.white,
                      semanticLabel: '入场码',
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: party.canAct ? legacyGold : Colors.white12,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        party.actionLabel,
                        style: TextStyle(
                          color: party.canAct ? Colors.black : Colors.white54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class TogetherParticipants extends StatelessWidget {
  const TogetherParticipants({super.key, required this.party});
  final TogetherParty party;
  @override
  Widget build(BuildContext context) {
    final visible = party.capacity.clamp(0, 10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: List.generate(visible, (index) {
            final member = index < party.participants.length
                ? party.participants[index]
                : null;
            return Semantics(
              label: member == null ? '待加入' : '${member.name}已报名',
              child: CircleAvatar(
                radius: 10,
                backgroundColor: member == null ? Colors.white12 : legacyGold,
                backgroundImage: member?.avatar == null
                    ? null
                    : NetworkImage(member!.avatar!),
                child: member?.avatar != null
                    ? null
                    : Icon(
                        Icons.person_outline,
                        size: 14,
                        color: member == null ? Colors.white24 : Colors.black87,
                      ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          '${party.participants.length}/${party.capacity} 人',
          style: const TextStyle(color: legacyPink, fontSize: 11),
        ),
        if (party.capacity > 10)
          Text(
            '还有 ${party.remaining} 个空位',
            style: const TextStyle(color: legacyPink, fontSize: 10),
          ),
      ],
    );
  }
}

class TogetherPartyDetailPage extends StatefulWidget {
  const TogetherPartyDetailPage({
    super.key,
    required this.party,
    required this.repository,
    required this.onJoin,
    required this.onAdmission,
  });
  final TogetherParty party;
  final TogetherPlayRepository repository;
  final Future<void> Function(TogetherParty) onJoin, onAdmission;
  @override
  State<TogetherPartyDetailPage> createState() =>
      _TogetherPartyDetailPageState();
}

class _TogetherPartyDetailPageState extends State<TogetherPartyDetailPage> {
  late TogetherParty _party = widget.party;
  bool _busy = false;
  String? _error;
  Future<void> _act() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final current = await widget.repository.detail(_party.ref);
      if (!mounted) return;
      setState(() => _party = current);
      if (!current.canAct) return;
      if (current.actionState == TogetherJoinState.joined) {
        await widget.onAdmission(current);
      } else {
        await widget.onJoin(current);
      }
      final updated = await widget.repository.detail(_party.ref);
      if (mounted) setState(() => _party = updated);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法处理，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LegacyClubScaffold(
    title: '组局详情',
    onBack: () => Navigator.pop(context),
    showMockLabel: false,
    child: Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              if (_party.posterUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _party.posterUrl!,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                _party.theme,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${_party.merchantHost ? '商家' : '会员'} ${_party.hostName} 发起',
                style: const TextStyle(color: legacyGold),
              ),
              const SizedBox(height: 10),
              Text(
                '${_party.startsAt.year}年 ${togetherTimeRange(_party)}\n${_party.cityName} · ${_party.storeName}\n${_party.place}',
                style: const TextStyle(color: Colors.white70, height: 1.8),
              ),
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 160,
                  child: TogetherParticipants(party: _party),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _party.feeLabel,
                style: const TextStyle(color: legacyGold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                _party.description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '报名须知',
                style: TextStyle(color: legacyGold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                _party.rules,
                style: const TextStyle(color: Colors.white54, height: 1.7),
              ),
            ],
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: legacyPink)),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _party.priceLabel,
                  style: const TextStyle(color: legacyGold, fontSize: 23),
                ),
              ),
              FilledButton.icon(
                onPressed: !_busy && _party.canAct ? _act : null,
                style: FilledButton.styleFrom(
                  backgroundColor: legacyGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 23,
                    vertical: 15,
                  ),
                ),
                icon: Icon(
                  _party.actionState == TogetherJoinState.joined
                      ? Icons.qr_code_2
                      : Icons.arrow_forward,
                  size: 20,
                ),
                label: Text(_busy ? '请稍候' : _party.actionLabel),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
