import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/media/cached_media_image.dart';

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

String togetherCardTimeRange(TogetherParty party) {
  final start = party.startsAt;
  final end = party.endsAt;
  final days = DateTime.utc(
    end.year,
    end.month,
    end.day,
  ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
  if (days < 0 || days > 1) return togetherTimeRange(party);
  return '${_date(start)} ${_time(start)}–${_time(end)}';
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
      final matching = items
          .where(
            (p) =>
                p.cityCode == widget.cityCode &&
                DateUtils.isSameDay(p.startsAt, date),
          )
          .toList();
      setState(
        () => _items = [
          ...matching.where((p) => p.hasAssignedTable),
          ...matching.where((p) => !p.hasAssignedTable),
        ],
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
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width * 30 / 750,
                    16,
                    MediaQuery.sizeOf(context).width * 30 / 750,
                    28,
                  ),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 16),
                  itemBuilder: (_, index) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_items[index].hasAssignedTable)
                        TogetherPartyCard(
                          party: _items[index],
                          onTap: () => _open(_items[index]),
                        )
                      else
                        TogetherAvailableRow(
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

/// Ticket geometry follows Choose.wxss: 690 by 240 rpx, 20 rpx corners.
class TogetherPartyCard extends StatelessWidget {
  const TogetherPartyCard({
    super.key,
    required this.party,
    required this.onTap,
  });
  final TogetherParty party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 690 / 240,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('together-card-${party.ref}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const RadialGradient(
              center: Alignment.bottomRight,
              // CSS circle 500rpx; Flutter measures radius against the
              // shortest side of this 690 by 240rpx ticket.
              radius: 500 / 240,
              colors: [Color(0xFFAD016A), Color(0xFF5A1E80)],
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
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: 345,
              height: 120,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 10, 12.5, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 135,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 45,
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.contain,
                                child: Text(
                                  party.assignedTable ?? '待分配',
                                  style: const TextStyle(
                                    fontFamily: 'AaRuizhi',
                                    fontSize: 50,
                                    // Exclude leading to match the old outline.
                                    height: .8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7.5),
                            FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TogetherStoreLogo(party: party),
                                  const SizedBox(width: 4),
                                  Text(
                                    party.storeName,
                                    style: _ticketStyle(
                                      context,
                                      12,
                                    ).copyWith(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Image.asset(
                              'assets/legacy/aa/positioningCard.png',
                              width: 135,
                              height: 18,
                              fit: BoxFit.contain,
                              semanticLabel: 'POSITIONING CARD',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            TogetherParticipants(
                              party: party,
                              showCount: false,
                            ),
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        party.theme,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: _ticketStyle(context, 13),
                                      ),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: _price(context),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (party.actionState ==
                                    TogetherJoinState.joined)
                                  Image.asset(
                                    'assets/legacy/aa/qrcode2.png',
                                    key: const ValueKey(
                                      'together-admission-icon',
                                    ),
                                    width: 40,
                                    height: 40,
                                    color: Colors.white,
                                    colorBlendMode: BlendMode.srcIn,
                                    semanticLabel: '入场码',
                                  )
                                else
                                  Container(
                                    constraints: const BoxConstraints(
                                      minWidth: 42,
                                      minHeight: 32,
                                    ),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: party.canAct
                                          ? legacyPink
                                          : Colors.white12,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      party.actionLabel,
                                      style: TextStyle(
                                        color: party.canAct
                                            ? const Color(0xFF65084E)
                                            : Colors.white54,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // The old global view rule sets gold; the ticket's inherited pink applies
  // to image artwork, not to these view text nodes. Keep the platform family
  // explicitly while discarding Material's extra tracking and line spacing.
  TextStyle _ticketStyle(BuildContext context, double size) {
    final platformStyle = Typography.material2021(
      platform: Theme.of(context).platform,
    ).white.bodyMedium;
    return togetherLegacyDateStyle(size, legacyGold).copyWith(
      fontFamily: platformStyle?.fontFamily,
      fontFamilyFallback: platformStyle?.fontFamilyFallback,
    );
  }

  Widget _price(BuildContext context) {
    final parts = party.priceLabel.split('/');
    final span = TextSpan(
      style: _ticketStyle(context, 20).copyWith(fontWeight: FontWeight.w600),
      children: [
        TextSpan(text: parts.first.replaceFirst('¥', '￥')),
        if (parts.length > 1)
          TextSpan(
            text: '/${parts.last}',
            style: const TextStyle(fontSize: 12),
          ),
      ],
    );
    return Text.rich(span, textScaler: TextScaler.noScaling);
  }
}

class TogetherStoreLogo extends StatelessWidget {
  const TogetherStoreLogo({super.key, required this.party});
  final TogetherParty party;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(3),
    child: Container(
      width: 16,
      height: 16,
      color: Colors.black,
      child: _image(),
    ),
  );

  Widget _image() {
    final source = party.storeLogo;
    if (source == null || source.isEmpty) {
      return const Icon(Icons.storefront, size: 12, color: Colors.white);
    }
    final asset = source.startsWith('assets/');
    if (Uri.parse(source).path.endsWith('.svg')) {
      const filter = ColorFilter.mode(Colors.white, BlendMode.srcIn);
      return asset
          ? SvgPicture.asset(
              source,
              colorFilter: filter,
              semanticsLabel: party.storeName,
            )
          : SvgPicture.network(
              source,
              colorFilter: filter,
              semanticsLabel: party.storeName,
            );
    }
    return asset
        ? Image.asset(source, fit: BoxFit.contain)
        : CachedMediaImage(source, fit: BoxFit.contain);
  }
}

/// Available parties stay in quiet, compact rows; a colored positioning
/// ticket is reserved for the member's confirmed table allocation.
class TogetherAvailableRow extends StatelessWidget {
  const TogetherAvailableRow({
    super.key,
    required this.party,
    required this.onTap,
  });
  final TogetherParty party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0x33C9B69E),
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      key: ValueKey('together-card-${party.ref}'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party.theme,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, color: legacyGold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${party.participants.length}/${party.capacity}人 · ${party.feeLabel}',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      TogetherStoreLogo(party: party),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          party.storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  party.priceLabel,
                  style: const TextStyle(fontSize: 14, color: legacyGold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF281903),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    party.state == TogetherJoinState.joined
                        ? '待分配卡座'
                        : party.actionLabel,
                    style: const TextStyle(fontSize: 13, color: legacyGold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Two rows of square seats, keeping the configured capacity visible.
/// Unknown gender remains neutral rather than inventing a male/female quota.
class TogetherParticipants extends StatelessWidget {
  const TogetherParticipants({
    super.key,
    required this.party,
    this.showCount = true,
  });
  final TogetherParty party;
  final bool showCount;
  @override
  Widget build(BuildContext context) {
    final columns = (party.capacity + 1) ~/ 2;
    final members = <int, TogetherParticipant>{};
    for (var i = 0; i < party.participants.length; i++) {
      final member = party.participants[i];
      members[member.seatIndex ?? i] = member;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          height: 50,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotSize = columns == 0
                  ? 24.0
                  : ((constraints.maxWidth - (columns - 1) * 2) / columns)
                        .clamp(18.0, 24.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    2,
                    (row) => Padding(
                      padding: EdgeInsets.only(top: row == 0 ? 0 : 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(columns, (col) {
                          final index = row * columns + col;
                          if (index >= party.capacity) {
                            return SizedBox(width: slotSize);
                          }
                          final member = members[index];
                          final gender =
                              member?.gender != null &&
                                  member!.gender != TogetherGender.unspecified
                              ? member.gender
                              : index < party.seatGenders.length
                              ? party.seatGenders[index]
                              : TogetherGender.unspecified;
                          final symbol = switch (gender) {
                            TogetherGender.male => 'assets/legacy/aa/man2.png',
                            TogetherGender.female =>
                              'assets/legacy/aa/woman.png',
                            TogetherGender.unspecified => null,
                          };
                          final fallback = Center(
                            child: symbol == null
                                ? Icon(
                                    Icons.person_outline,
                                    size: 16,
                                    color: const Color(0xFF9C277E),
                                  )
                                : Image.asset(
                                    symbol,
                                    height: 15,
                                    fit: BoxFit.contain,
                                  ),
                          );
                          final avatar = member?.avatar;
                          return Padding(
                            padding: EdgeInsets.only(left: col == 0 ? 0 : 2),
                            child: Semantics(
                              label: member == null
                                  ? '待加入'
                                  : '${member.name}已报名',
                              child: Opacity(
                                opacity: member == null ? .3 : 1,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(1),
                                  child: Container(
                                    key: ValueKey('seat-${party.ref}-$index'),
                                    width: slotSize,
                                    height: slotSize,
                                    decoration: BoxDecoration(
                                      color: legacyPink,
                                      gradient: member == null
                                          ? null
                                          : const RadialGradient(
                                              colors: [
                                                Colors.white,
                                                legacyPink,
                                              ],
                                              radius: .9,
                                            ),
                                    ),
                                    child: avatar == null || avatar.isEmpty
                                        ? fallback
                                        : avatar.startsWith('assets/')
                                        ? Image.asset(
                                            avatar,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => fallback,
                                          )
                                        : CachedMediaImage(
                                            avatar,
                                            width: slotSize,
                                            height: slotSize,
                                            placeholder: fallback,
                                            errorBuilder: (_, _, _) => fallback,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (showCount) ...[
          const SizedBox(height: 6),
          Text(
            '${party.participants.length}/${party.capacity} 人',
            style: const TextStyle(color: legacyPink, fontSize: 11),
          ),
        ],
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
