import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/king_components.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_date_picker.dart';
import 'together_play_page.dart';
import 'together_removal_page.dart';

/// Old ticket.wxml geometry, populated only by the selected member ticket.
class TogetherTicketPage extends StatefulWidget {
  const TogetherTicketPage({
    super.key,
    required this.party,
    this.reload,
    this.removalRepository,
    this.clock = DateTime.now,
  });
  final TogetherParty party;
  final Future<TogetherParty> Function()? reload;
  final DateTime Function() clock;
  final TogetherRemovalRepository? removalRepository;

  @override
  State<TogetherTicketPage> createState() => _TogetherTicketPageState();
}

class _TogetherTicketPageState extends State<TogetherTicketPage>
    with WidgetsBindingObserver {
  bool _covered = false;
  late TogetherParty _party;
  bool _checking = false;
  bool _refreshFailed = false;
  int _generation = 0;
  Timer? _timer;

  bool get _codeExpired =>
      _party.admissionExpiresAt != null &&
      !widget.clock().toUtc().isBefore(_party.admissionExpiresAt!);

  bool get _expired => !widget.clock().isBefore(_party.endsAt);

  @override
  void initState() {
    super.initState();
    _party = widget.party;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _covered = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if (!_covered) _refresh();
  }

  @override
  void didUpdateWidget(TogetherTicketPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.party != widget.party || oldWidget.reload != widget.reload) {
      _generation++;
      _timer?.cancel();
      _party = widget.party;
      _checking = false;
      _refreshFailed = false;
      if (!_covered) _refresh();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_covered || _expired) return;
    final remaining = _party.endsAt.difference(widget.clock());
    var delay = widget.reload != null && remaining > const Duration(seconds: 30)
        ? const Duration(seconds: 30)
        : remaining;
    final expiry = _party.admissionExpiresAt;
    if (expiry != null && !_codeExpired) {
      final codeRemaining = expiry.difference(widget.clock().toUtc());
      if (codeRemaining < delay) delay = codeRemaining;
    }
    _timer = Timer(delay, () {
      if (!mounted || _covered) return;
      setState(() {});
      if (!_expired) _refresh();
    });
  }

  Future<void> _refresh({bool hideUntilChecked = true}) async {
    final reload = widget.reload;
    if (reload == null || _expired) {
      _schedule();
      return;
    }
    final generation = ++_generation;
    _timer?.cancel();
    setState(() => _checking = hideUntilChecked || _refreshFailed);
    try {
      final updated = await reload().timeout(const Duration(seconds: 10));
      if (!mounted || generation != _generation || _covered) return;
      if (updated.ref != widget.party.ref ||
          updated.storeRef != widget.party.storeRef ||
          (_party.ticketNumber != null &&
              updated.ticketNumber != _party.ticketNumber)) {
        throw StateError('Ticket identity changed');
      }
      setState(() {
        _party = updated;
        _refreshFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation || _covered) return;
      setState(() => _refreshFailed = true);
    } finally {
      if (mounted && generation == _generation && !_covered) {
        setState(() => _checking = false);
        _schedule();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    _generation++;
    _timer?.cancel();
    setState(() {
      _covered = state != AppLifecycleState.resumed;
      _checking = false;
    });
    if (!_covered) _refresh();
  }

  @override
  void dispose() {
    _generation++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final party = _party;
    final unit = MediaQuery.sizeOf(context).width / 750;
    final safeTop = MediaQuery.paddingOf(context).top;
    final cardTop = (130 * unit).clamp(safeTop, double.infinity) + 89 * unit;
    TextStyle style(double size, [Color color = legacyGold]) =>
        togetherLegacyDateStyle(size * unit, color).copyWith(
          height: 40 / 28,
          fontFamily: Typography.material2021(
            platform: Theme.of(context).platform,
          ).white.bodyMedium?.fontFamily,
        );
    Widget line(String text, {Key? key}) =>
        Text(text, key: key, textAlign: TextAlign.center, style: style(28));
    final columns = (party.capacity + 1) ~/ 2;
    final code = party.admissionCode;
    final codeAvailable =
        party.hasAdmissionTicket &&
        !party.admissionUsed &&
        code != null &&
        code.isNotEmpty &&
        !_covered &&
        !_expired &&
        !_codeExpired &&
        !_checking &&
        !_refreshFailed;
    final codeStatus = _covered
        ? '入场码已遮盖'
        : party.admissionUsed
        ? '已入场'
        : party.state == TogetherJoinState.cancelled
        ? '活动已取消'
        : _expired
        ? '已过期'
        : _checking
        ? '正在更新入场码'
        : _refreshFailed
        ? '入场码暂未更新'
        : '入场码暂不可用';
    return Scaffold(
      backgroundColor: const Color(0xFF12020C),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.5),
            radius: 600 / 750,
            colors: [Color(0xFF470F24), Color(0xFF12020C)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              top: cardTop,
              child: SingleChildScrollView(
                key: const ValueKey('together-ticket-scroll'),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 20,
                ),
                child: Column(
                  children: [
                    Container(
                      key: const ValueKey('together-ticket-sheet'),
                      width: 690 * unit,
                      padding: EdgeInsets.fromLTRB(
                        20 * unit,
                        50 * unit,
                        20 * unit,
                        80 * unit,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20 * unit),
                        // CSS circle 500rpx; the narrow side is the 690rpx width.
                        gradient: const RadialGradient(
                          center: Alignment.bottomRight,
                          radius: 500 / 690,
                          colors: [Color(0xFFAD016A), Color(0xFF5A1E80)],
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 90 * unit,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                party.hasAssignedTable
                                    ? party.assignedTable!
                                    : '待分配',
                                key: const ValueKey('together-ticket-table'),
                                style: TextStyle(
                                  fontFamily: party.hasAssignedTable
                                      ? 'AaRuizhi'
                                      : null,
                                  color: Colors.white,
                                  fontSize:
                                      (party.hasAssignedTable ? 110 : 40) *
                                      unit,
                                  height: .8,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20 * unit),
                          line('POSITIONING CARD'),
                          line(
                            '${party.startsAt.year}-${togetherCardTimeRange(party).replaceFirst('.', '-')}',
                          ),
                          SizedBox(height: 30 * unit),
                          if (columns > 0)
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                width: (columns * 74 - 4) * unit,
                                child: TogetherParticipants(
                                  party: party,
                                  showCount: false,
                                  seatSize: 70 * unit,
                                  seatGap: 4 * unit,
                                  iconHeight: 38 * unit,
                                ),
                              ),
                            ),
                          SizedBox(height: 50 * unit),
                          Container(
                            key: const ValueKey('together-ticket-qr-frame'),
                            width: 440 * unit,
                            height: 440 * unit,
                            color: Colors.white,
                            padding: EdgeInsets.all(46 * unit),
                            child: codeAvailable
                                ? QrImageView(
                                    data: code,
                                    padding: EdgeInsets.zero,
                                    errorCorrectionLevel: QrErrorCorrectLevel.H,
                                    backgroundColor: Colors.white,
                                    embeddedImage: const AssetImage(
                                      'assets/legacy/aa/kingLogo.png',
                                    ),
                                    embeddedImageStyle: QrEmbeddedImageStyle(
                                      size: Size(84 * unit, 84 * unit),
                                    ),
                                    semanticsLabel: '${party.theme}入场二维码',
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          codeStatus,
                                          textAlign: TextAlign.center,
                                          style: style(
                                            30,
                                            const Color(0xFF5A1E80),
                                          ),
                                        ),
                                        if (_refreshFailed &&
                                            !_covered &&
                                            !_expired &&
                                            !_codeExpired &&
                                            !_checking)
                                          TextButton(
                                            onPressed: _refresh,
                                            child: const Text('重新加载'),
                                          ),
                                      ],
                                    ),
                                  ),
                          ),
                          SizedBox(height: 10 * unit),
                          if (party.ticketNumber?.isNotEmpty == true)
                            line(party.ticketNumber!),
                          line(party.theme),
                          Row(
                            key: const ValueKey('together-ticket-store'),
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TogetherStoreLogo(party: party, size: 34 * unit),
                              SizedBox(width: 8 * unit),
                              Flexible(child: line(party.storeName)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.removalRepository != null)
                      TextButton(
                        onPressed: () async {
                          await Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => TogetherRemovalPage(
                                partyRef: party.ref,
                                repository: widget.removalRepository!,
                              ),
                            ),
                          );
                          if (mounted) await _refresh();
                        },
                        child: const Text('查看本场参加者'),
                      ),
                    Container(
                      width: 650 * unit,
                      margin: EdgeInsets.symmetric(vertical: 40 * unit),
                      child: DefaultTextStyle(
                        style: style(26, const Color(0x99C9B69E)),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 3),
                              child: Text('入场须知'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 3),
                              child: Text('1、请衣着整洁、文明礼貌，尊重同桌。'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 3),
                              child: Text('2、票券权益以活动说明为准，额外消费另付。'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 3),
                              child: Text('3、请按活动时间出示入场码，过期作废。'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: safeTop,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text('POSITIONING CARD', style: style(28)),
                  Positioned(
                    left: KingBackButton.leftOffset(context),
                    top: KingBackButton.safeAreaOffset.dy,
                    child: KingBackButton(
                      onPressed: () => Navigator.of(context).pop(),
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
