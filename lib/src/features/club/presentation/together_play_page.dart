import 'dart:ui' show ImageFilter;

import 'package:kingclub/src/core/formatters/money.dart';

import '../../../core/design_system/king_language.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/media/cached_media_image.dart';

import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'positioning_card_label.dart';
import 'together_date_picker.dart';
import 'together_ticket_page.dart';
import 'together_artwork_contrast.dart';
import 'together_removal_page.dart';

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
    this.onSelectCity,
    this.reviewOnly = false,
  });
  final TogetherPlayRepository repository;
  final String cityCode, cityName;
  final VoidCallback onBack, onCreate;
  final Future<void> Function(TogetherParty) onJoin, onAdmission;
  final DateTime? today;
  final VoidCallback? onSelectCity;
  final bool reviewOnly;
  @override
  State<TogetherPlayPage> createState() => _TogetherPlayPageState();
}

class _TogetherPlayPageState extends State<TogetherPlayPage>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading) _load();
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
        MaterialPageRoute(
          builder: (_) => TogetherTicketPage(
            party: party,
            removalRepository:
                !widget.reviewOnly &&
                    widget.repository is TogetherRemovalRepository
                ? widget.repository as TogetherRemovalRepository
                : null,
            reload: widget.reviewOnly
                ? null
                : () => widget.repository is TogetherAdmissionRepository
                      ? (widget.repository as TogetherAdmissionRepository)
                            .admission(party.ref)
                      : widget.repository.detail(party.ref),
          ),
        ),
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
    title: kingText(Localizations.localeOf(context), [
      'AA邀请',
      'AA invitations',
      'AA邀請',
      'คำเชิญแบบ AA',
    ]),
    cityName: widget.cityName,
    onSelectCity: widget.onSelectCity,
    onBack: widget.onBack,
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
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
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
    required this.cityName,
    this.onSelectCity,
    required this.onBack,
    required this.child,
  });
  final String title, cityName;
  final VoidCallback? onSelectCity;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final unit = MediaQuery.sizeOf(context).width / 750;
    final safeTop = MediaQuery.paddingOf(context).top;
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
                    Center(
                      child: Text(
                        title,
                        key: const ValueKey('together-title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Positioned(
                      left: KingBackButton.leftOffset(context),
                      top: KingBackButton.safeAreaOffset.dy,
                      child: KingBackButton(onPressed: onBack),
                    ),
                    if (onSelectCity != null)
                      Positioned(
                        right: 30 * unit,
                        top: 6,
                        width: 90,
                        child: TextButton(
                          key: const ValueKey('together-city-selector'),
                          onPressed: onSelectCity,
                          style: TextButton.styleFrom(
                            foregroundColor: legacyGold,
                            minimumSize: const Size(44, 44),
                            padding: EdgeInsets.zero,
                            textStyle: togetherLegacyDateStyle(
                              26 * unit,
                              legacyGold,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  cityName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, size: 16),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Keep content below the shared 56 dp conversation header.
              Column(
                children: [
                  SizedBox(height: safeTop + 56),
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
class TogetherTicketTheme extends StatelessWidget {
  const TogetherTicketTheme({
    super.key,
    required this.theme,
    required this.style,
  });
  final String theme;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final measure = TextPainter(
        text: TextSpan(text: theme, style: style),
        maxLines: 1,
        textDirection: Directionality.of(context),
      )..layout(maxWidth: constraints.maxWidth);
      final wraps = measure.didExceedMaxLines;
      measure.dispose();
      return Text(
        theme,
        key: const ValueKey('together-ticket-theme'),
        maxLines: wraps ? 2 : 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: wraps ? style.copyWith(fontSize: 12) : style,
      );
    },
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
                                        TogetherTicketTheme(
                                          theme: party.theme,
                                          style: _ticketStyle(context, 14)
                                              .copyWith(
                                                height: 1.15,
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

/// Balance a two-line headline without shrinking its App Store type size.
/// Keep words intact and avoid beginning the second line with punctuation.
String togetherEditorialHeadline(
  String title,
  TextStyle style,
  double width,
  TextScaler scaler,
  TextDirection direction,
) {
  final letters = title.characters.toList();
  if (letters.length < 2 || letters.length > 80) return title;
  final painter = TextPainter(textDirection: direction, textScaler: scaler);
  double measure(String text) {
    painter.text = TextSpan(text: text, style: style);
    painter.layout();
    return painter.width;
  }

  try {
    if (measure(title) <= width) return title;
    final word = RegExp(r'^[a-zA-Z0-9]$');
    const closing = '，。！？：；、,.!?;:)]}》」』';
    const opening = '([{《「『';
    String? balanced;
    var best = double.infinity;
    var bestAtSeparator = false;
    for (var i = 1; i < letters.length; i++) {
      if (word.hasMatch(letters[i - 1]) && word.hasMatch(letters[i])) continue;
      final first = letters.take(i).join().trim();
      final second = letters.skip(i).join().trim();
      if (first.isEmpty ||
          second.isEmpty ||
          closing.contains(second.characters.first) ||
          opening.contains(first.characters.last)) {
        continue;
      }
      final firstWidth = measure(first);
      final secondWidth = measure(second);
      if (firstWidth > width || secondWidth > width) continue;
      final cost = (firstWidth - secondWidth).abs();
      final atSeparator =
          RegExp(r'[，,：:；;、]$').hasMatch(first) &&
          firstWidth >= width * .35 &&
          secondWidth >= width * .35;
      if ((atSeparator && !bestAtSeparator) ||
          (atSeparator == bestAtSeparator && cost < best)) {
        bestAtSeparator = atSeparator;
        best = cost;
        balanced = '$first\n$second';
      }
    }
    return balanced ?? title;
  } finally {
    painter.dispose();
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
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(
      horizontal: MediaQuery.sizeOf(context).width * .01,
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = (constraints.maxWidth / 353).clamp(.8, 1.15);
        final inset = 20 * scale;
        final poster = party.detailPosters.firstOrNull;
        final summary = party.merchantHost;
        return TogetherArtworkContrast(
          source: poster,
          aspectRatio: 353 / 435,
          builder: (context, ink) {
            final cupertino = CupertinoTheme.of(context).textTheme;
            final ios = Theme.of(context).platform == TargetPlatform.iOS;
            TextStyle textStyle(
              double size, {
              Color? color,
              FontWeight weight = FontWeight.w400,
              double height = 1.2,
            }) =>
                (ios
                        ? (size >= 20
                              ? cupertino.navLargeTitleTextStyle
                              : cupertino.textStyle)
                        : const TextStyle())
                    .copyWith(
                      fontSize: size * scale,
                      color: color ?? ink.primary,
                      fontWeight: weight,
                      height: height,
                      letterSpacing: 0,
                    );
            Widget artwork({double? size}) {
              final image = poster == null || !ink.ready
                  ? const ColoredBox(color: Color(0xFF393229))
                  : poster.startsWith('assets/')
                  ? Image.asset(poster, fit: BoxFit.cover)
                  : CachedMediaImage(poster, fit: BoxFit.cover);
              return size == null
                  ? image
                  : SizedBox.square(dimension: size, child: image);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  key: ValueKey('together-heading-${party.ref}'),
                  padding: EdgeInsets.only(bottom: 12 * scale, top: 6),
                  child: GestureDetector(
                    onTap: onTap,
                    child: Text(
                      party.theme,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textStyle(
                        20,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(22 * scale),
                  child: Material(
                    color: const Color(0xFF29251F),
                    child: InkWell(
                      key: ValueKey('together-card-${party.ref}'),
                      onTap: onTap,
                      child: Stack(
                        children: [
                          Positioned.fill(child: artwork()),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0, .4, .78, 1],
                                    colors: [
                                      Colors.transparent,
                                      ink.veil.withValues(alpha: .02),
                                      ink.veil.withValues(
                                        alpha: ink.black ? .08 : .30,
                                      ),
                                      ink.veil.withValues(alpha: .18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConstrainedBox(
                                key: ValueKey(
                                  'together-artwork-region-${party.ref}',
                                ),
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxWidth * 357 / 353,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    inset,
                                    0,
                                    inset,
                                    18 * scale,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        party.feeLabel,
                                        key: ValueKey(
                                          'together-kicker-${party.ref}',
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: textStyle(
                                          12,
                                          weight: FontWeight.w600,
                                          color: ink.secondary,
                                        ),
                                      ),
                                      SizedBox(height: 4 * scale),
                                      Text(
                                        togetherEditorialHeadline(
                                          party.theme,
                                          textStyle(
                                            24,
                                            weight: FontWeight.w700,
                                            height: 1.15,
                                          ),
                                          constraints.maxWidth - 2 * inset,
                                          MediaQuery.textScalerOf(context),
                                          Directionality.of(context),
                                        ),
                                        semanticsLabel: party.theme,
                                        key: ValueKey(
                                          'together-editorial-title-${party.ref}',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textStyle(
                                          24,
                                          weight: FontWeight.w700,
                                          height: 1.15,
                                        ),
                                      ),
                                      SizedBox(height: 8 * scale),
                                      Text(
                                        party.description.trim().isEmpty
                                            ? party.place
                                            : party.description.trim(),
                                        key: ValueKey(
                                          'together-editorial-subtitle-${party.ref}',
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: textStyle(
                                          13,
                                          color: ink.secondary,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ClipRect(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                    sigmaX: 12,
                                    sigmaY: 12,
                                  ),
                                  child: ColoredBox(
                                    color: ink.glass,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: inset,
                                        vertical: 15 * scale,
                                      ),
                                      child: summary
                                          ? Row(
                                              key: ValueKey(
                                                'together-summary-footer-${party.ref}',
                                              ),
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        10 * scale,
                                                      ),
                                                  child: artwork(
                                                    size: 48 * scale,
                                                  ),
                                                ),
                                                SizedBox(width: 10 * scale),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        party.theme,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: textStyle(
                                                          16,
                                                          weight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      SizedBox(
                                                        height: 3 * scale,
                                                      ),
                                                      Text(
                                                        party.priceLabel,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: textStyle(
                                                          13,
                                                          color: ink.secondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                SizedBox(width: 10 * scale),
                                                TextButton(
                                                  key: ValueKey(
                                                    'together-summary-open-${party.ref}',
                                                  ),
                                                  onPressed: onTap,
                                                  style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.white,
                                                    backgroundColor: ink.black
                                                        ? Colors.black
                                                              .withValues(
                                                                alpha: .42,
                                                              )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: .22,
                                                              ),
                                                    minimumSize: Size(
                                                      72 * scale,
                                                      32 * scale,
                                                    ),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize
                                                            .padded,
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              14 * scale,
                                                          vertical: 6 * scale,
                                                        ),
                                                    shape:
                                                        const StadiumBorder(),
                                                    textStyle: textStyle(
                                                      16,
                                                      weight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  child: const Text('查看'),
                                                ),
                                              ],
                                            )
                                          : TogetherParticipants(
                                              key: ValueKey(
                                                'together-seats-footer-${party.ref}',
                                              ),
                                              party: party,
                                              showCount: false,
                                              seatSize: 48 * scale,
                                              seatGap:
                                                  ((constraints.maxWidth -
                                                              2 * inset -
                                                              5 * 48 * scale) /
                                                          4)
                                                      .clamp(0.0, 30.0),
                                              iconHeight: 28 * scale,
                                              singleRow: true,
                                              cornerRadius: 11 * scale,
                                            ),
                                    ),
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
              ],
            );
          },
        );
      },
    ),
  );
}

/// Tickets use two rows; editorial cards use a horizontally scrollable strip.
/// Unknown gender remains neutral rather than inventing a male/female quota.
class TogetherParticipants extends StatelessWidget {
  const TogetherParticipants({
    super.key,
    required this.party,
    this.showCount = true,
    this.seatSize = 24,
    this.seatGap = 2,
    this.iconHeight = 15,
    this.singleRow = false,
    this.cornerRadius = 1,
  });
  final TogetherParty party;
  final bool showCount;
  final double seatSize, seatGap, iconHeight, cornerRadius;
  final bool singleRow;
  @override
  Widget build(BuildContext context) {
    final rows = singleRow ? 1 : 2;
    final columns = (party.capacity + rows - 1) ~/ rows;
    final members = <int, TogetherParticipant>{};
    for (var i = 0; i < party.participants.length; i++) {
      final member = party.participants[i];
      members[member.seatIndex ?? i] = member;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          height: seatSize * rows + seatGap * (rows - 1),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotSize = singleRow || columns == 0
                  ? seatSize
                  : ((constraints.maxWidth - (columns - 1) * seatGap) / columns)
                        .clamp(18.0, seatSize);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(
                    rows,
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
                              : index < (party.capacity + 1) ~/ 2
                              ? TogetherGender.male
                              : TogetherGender.female;
                          final symbol = switch (gender) {
                            TogetherGender.male => 'assets/legacy/aa/man2.png',
                            TogetherGender.female =>
                              'assets/legacy/aa/woman.png',
                            TogetherGender.unspecified => null,
                          };
                          final genderIcon = Center(
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
                          final fallback = genderIcon;
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
                                  borderRadius: BorderRadius.circular(
                                    cornerRadius,
                                  ),
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
                                    child: member?.avatarBytes != null
                                        ? Image.memory(
                                            member!.avatarBytes!,
                                            key: ValueKey(
                                              'seat-avatar-${party.ref}-$index',
                                            ),
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                            errorBuilder: (_, _, _) => fallback,
                                          )
                                        : avatar == null || avatar.isEmpty
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
            '${party.participantCount}/${party.capacity} 人',
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
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final party = await widget.repository.detail(widget.party.ref);
      if (party.ref != widget.party.ref) throw StateError('Activity mismatch');
      if (mounted) {
        setState(() {
          _party = party;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法加载活动详情');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
              if (_party.detailPosters.isNotEmpty)
                _TogetherPosters(
                  key: ValueKey(_party.detailPosters.join('\n')),
                  urls: _party.detailPosters,
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
                '${_party.publisherLabel} ${_party.hostName} 发起',
                style: const TextStyle(color: legacyGold),
              ),
              const SizedBox(height: 10),
              Text(
                '${_party.startsAt.year}年 ${togetherTimeRange(_party)}\n${_party.cityName} · ${_party.storeName}\n${_party.place}',
                style: const TextStyle(color: Colors.white70, height: 1.8),
              ),
              const SizedBox(height: 22),
              if (_party.collaboratorHost && _party.assignedTable != null)
                Text(
                  '位置 ${_party.assignedTable} · 已加入 ${_party.participantCount}/${_party.capacity} 人',
                  style: const TextStyle(color: Colors.white, fontSize: 17),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 160,
                  child: TogetherParticipants(party: _party),
                ),
              ),
              if (widget.repository is TogetherRemovalRepository)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => TogetherRemovalPage(
                                partyRef: _party.ref,
                                repository:
                                    widget.repository
                                        as TogetherRemovalRepository,
                              ),
                            ),
                          );
                          if (mounted) {
                            await _refresh();
                          }
                        },
                  child: const Text('查看本场参加者'),
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
              if (_party.eligible != null) ...[
                const SizedBox(height: 20),
                Text(
                  _party.eligible!
                      ? '你符合本场活动要求'
                      : _party.eligibilityReasons.join('\n'),
                  style: TextStyle(
                    color: _party.eligible! ? legacyGold : legacyPink,
                    height: 1.6,
                  ),
                ),
              ],
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
          TextButton(
            onPressed: _busy ? null : _refresh,
            child: Text(
              '$_error · 重试',
              style: const TextStyle(color: legacyPink),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _party.personalPriceMinor == null
                      ? _party.priceLabel
                      : '应付 ¥${moneyAmount((_party.personalPriceMinor! / 100))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: legacyGold, fontSize: 23),
                ),
              ),
              FilledButton.icon(
                onPressed: !_busy && _loaded && _party.canAct ? _act : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 52),
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

class _TogetherPosters extends StatefulWidget {
  const _TogetherPosters({super.key, required this.urls});
  final List<String> urls;

  @override
  State<_TogetherPosters> createState() => _TogetherPostersState();
}

class _TogetherPostersState extends State<_TogetherPosters> {
  int _page = 0;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AspectRatio(
      aspectRatio: 3 / 4,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) => ColoredBox(
              color: Colors.black,
              child: CachedMediaImage(
                widget.urls[index],
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(
                  child: Text(
                    '海报暂未加载',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              right: 12,
              bottom: 12,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '${_page + 1}/${widget.urls.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
