import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';

import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'positioning_card_label.dart';
import 'together_date_picker.dart';
import 'together_ticket_page.dart';

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
          ...matching.where((p) => p.hasAdmissionTicket),
          ...matching.where((p) => !p.hasAdmissionTicket),
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
    if (party.hasAdmissionTicket) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => TogetherTicketPage(party: party)),
      );
      if (mounted && !widget.reviewOnly) await _load();
      return;
    }
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
  Widget build(BuildContext context) => _TogetherScaffold(
    title: '一起玩',
    onBack: widget.onBack,
    onCreate: widget.onCreate,
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
                    0,
                    MediaQuery.sizeOf(context).width * 30 / 750,
                    28,
                  ),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => SizedBox(
                    height: MediaQuery.sizeOf(context).width * 30 / 750,
                  ),
                  itemBuilder: (_, index) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_items[index].hasAdmissionTicket) ...[
                        TogetherPartyCard(
                          party: _items[index],
                          onTap: () => _open(_items[index]),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.sizeOf(context).width * 20 / 750,
                          ),
                          child: Text(
                            '请按时到场并出示入场码，过期作废。\n'
                            '请衣着整洁、文明礼貌，适量饮酒、尊重同桌。',
                            key: ValueKey(
                              'together-use-reminder-${_items[index].ref}',
                            ),
                            style: togetherLegacyDateStyle(
                              MediaQuery.sizeOf(context).width * 26 / 750,
                              const Color(0x66FFFFFF),
                            ).copyWith(height: 1.55),
                          ),
                        ),
                      ] else
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

/// Choose.wxss starts at 130rpx from the screen, not below a second app bar.
/// Keep this page-specific so other screens retain their shared navigation.
class _TogetherScaffold extends StatelessWidget {
  const _TogetherScaffold({
    required this.title,
    required this.onBack,
    required this.onCreate,
    required this.child,
  });
  final String title;
  final VoidCallback onBack, onCreate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final unit = MediaQuery.sizeOf(context).width / 750;
    final safeTop = MediaQuery.paddingOf(context).top;
    final top = (130 * unit).clamp(safeTop, double.infinity);
    return Scaffold(
      backgroundColor: Colors.black,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.5),
            radius: 600 / 750,
            colors: [Color(0xEF252018), Colors.black],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: safeTop,
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      title,
                      key: const ValueKey('together-title'),
                      style: togetherLegacyDateStyle(
                        28 * unit,
                        legacyGold,
                      ).copyWith(height: 39 / 28),
                    ),
                    Positioned(
                      left: KingBackButton.leftOffset(context),
                      top: KingBackButton.safeAreaOffset.dy,
                      child: KingBackButton(onPressed: onBack),
                    ),
                    Positioned(
                      right: 30 * unit,
                      top: 6,
                      child: TextButton(
                        onPressed: onCreate,
                        style: TextButton.styleFrom(
                          foregroundColor: legacyGold,
                          minimumSize: const Size(44, 44),
                          padding: EdgeInsets.zero,
                          textStyle: togetherLegacyDateStyle(
                            26 * unit,
                            legacyGold,
                          ),
                        ),
                        child: const Text('发起组局'),
                      ),
                    ),
                  ],
                ),
              ),
              // Keep the accepted content coordinates. Date hit targets paint
              // above the navigation row where the compact layouts overlap.
              Column(
                children: [
                  SizedBox(height: top + 39 * unit),
                  Expanded(child: child),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legacy proportions, with the requested extra height for the merchant mark.
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
    aspectRatio: 690 / 232,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('together-card-${party.ref}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          MediaQuery.sizeOf(context).width * 20 / 750,
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              MediaQuery.sizeOf(context).width * 20 / 750,
            ),
            gradient: const RadialGradient(
              center: Alignment.bottomRight,
              // CSS circle 500rpx; Flutter measures radius against the
              // shortest side of this 690 by 232rpx ticket.
              radius: 500 / 232,
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
              height: 116,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(15, 8, 12.5, 8),
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
                              height: 40,
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.contain,
                                child: Text(
                                  party.assignedTable ?? '待分配',
                                  style: const TextStyle(
                                    fontFamily: 'AaRuizhi',
                                    fontSize: 45,
                                    // Exclude leading to match the old outline.
                                    height: .8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7.5),
                            SizedBox(
                              height: 29,
                              child: Row(
                                children: [
                                  TogetherStoreLogo(party: party),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: FittedBox(
                                      alignment: Alignment.centerLeft,
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        party.storeName,
                                        style: _ticketStyle(
                                          context,
                                          12,
                                        ).copyWith(color: legacyPink),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const PositioningCardLabel(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          // Match the left column's content height so the
                          // date, QR and English label share one bottom edge.
                          height: 98.5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TogetherParticipants(
                                party: party,
                                showCount: false,
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          party.theme,
                                          maxLines:
                                              party.actionState ==
                                                  TogetherJoinState.joined
                                              ? 2
                                              : 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: _ticketStyle(context, 16)
                                              .copyWith(
                                                height: 1,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (party.actionState ==
                                            TogetherJoinState.joined)
                                          const SizedBox(height: 3),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child:
                                              party.actionState ==
                                                  TogetherJoinState.joined
                                              ? Text(
                                                  togetherCardTimeRange(party),
                                                  style:
                                                      _ticketStyle(
                                                        context,
                                                        10,
                                                      ).copyWith(
                                                        height: 1.2,
                                                        color: Colors.white70,
                                                      ),
                                                )
                                              : _price(context),
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
  const TogetherStoreLogo({super.key, required this.party, this.size = 20});
  final TogetherParty party;
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(4),
    child: Container(
      width: size,
      height: size,
      color: Colors.black,
      child: _image(),
    ),
  );

  Widget _image() {
    final source = party.storeLogo;
    if (source == null || source.isEmpty) {
      return const Icon(Icons.storefront, size: 15, color: Colors.white);
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

/// One invitation per host and party, separate from the member's tickets.
class TogetherAvailableRow extends StatelessWidget {
  const TogetherAvailableRow({
    super.key,
    required this.party,
    required this.onTap,
  });
  final TogetherParty party;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unit = MediaQuery.sizeOf(context).width / 750;
    TextStyle style(double rpx, Color color) =>
        togetherLegacyDateStyle(rpx * unit, color).copyWith(height: 1.2);
    final background = party.backgroundUrl?.trim();
    final rules = party.rules.trim().replaceAll(RegExp(r'\s+'), ' ');
    return ClipRRect(
      borderRadius: BorderRadius.circular(20 * unit),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF40392E), Color(0xFF25221C)],
                ),
              ),
            ),
          ),
          if (background != null && background.isNotEmpty)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedMediaImage(
                    background,
                    key: ValueKey(
                      'together-invitation-background-${party.ref}',
                    ),
                    placeholder: const SizedBox.shrink(),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                  const ColoredBox(color: Color(0x99000000)),
                ],
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('together-card-${party.ref}'),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.all(24 * unit),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        TogetherStoreLogo(party: party, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                party.storeName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style(26, legacyPink),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${party.merchantHost ? '商家发起' : '会员发起'} · ${party.hostName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style(22, Colors.white54),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      party.theme,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style(
                        34,
                        legacyGold,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      rules.isEmpty ? party.feeLabel : rules,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: style(24, Colors.white60),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                party.priceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style(
                                  32,
                                  legacyGold,
                                ).copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${party.participants.length}/${party.capacity}人 · ${party.feeLabel}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: style(22, Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          key: ValueKey(
                            'together-invitation-action-${party.ref}',
                          ),
                          onPressed: party.canAct ? onTap : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: legacyGold,
                            foregroundColor: const Color(0xFF281903),
                            disabledBackgroundColor: Colors.white12,
                            disabledForegroundColor: Colors.white38,
                            minimumSize: Size(180 * unit, 44),
                            textStyle: style(
                              26,
                              const Color(0xFF281903),
                            ).copyWith(fontWeight: FontWeight.w600),
                          ),
                          child: Text(
                            party.actionState == TogetherJoinState.available
                                ? '抢位'
                                : party.actionLabel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Two rows of square seats, keeping the configured capacity visible.
/// Unknown gender remains neutral rather than inventing a male/female quota.
class TogetherParticipants extends StatelessWidget {
  const TogetherParticipants({
    super.key,
    required this.party,
    this.showCount = true,
    this.seatSize = 24,
    this.seatGap = 2,
    this.iconHeight = 15,
  });
  final TogetherParty party;
  final bool showCount;
  final double seatSize, seatGap, iconHeight;
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
          height: seatSize * 2 + seatGap,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotSize = columns == 0
                  ? seatSize
                  : ((constraints.maxWidth - (columns - 1) * seatGap) / columns)
                        .clamp(18.0, seatSize);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    2,
                    (row) => Padding(
                      padding: EdgeInsets.only(top: row == 0 ? 0 : seatGap),
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
                                    size: iconHeight,
                                    color: const Color(0xFF9C277E),
                                  )
                                : Image.asset(
                                    symbol,
                                    height: iconHeight,
                                    fit: BoxFit.contain,
                                  ),
                          );
                          final avatar = member?.avatar;
                          return Padding(
                            padding: EdgeInsets.only(
                              left: col == 0 ? 0 : seatGap,
                            ),
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
