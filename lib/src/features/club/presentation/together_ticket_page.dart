import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/king_components.dart';
import '../data/together_play.dart';
import 'legacy_club_components.dart';
import 'together_date_picker.dart';
import 'together_play_page.dart';

/// Old ticket.wxml geometry, populated only by the selected member ticket.
class TogetherTicketPage extends StatefulWidget {
  const TogetherTicketPage({super.key, required this.party});
  final TogetherParty party;

  @override
  State<TogetherTicketPage> createState() => _TogetherTicketPageState();
}

class _TogetherTicketPageState extends State<TogetherTicketPage>
    with WidgetsBindingObserver {
  bool _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() => _covered = state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final party = widget.party;
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
        !_covered;
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
                                    child: Text(
                                      _covered
                                          ? '入场码已遮盖'
                                          : party.admissionUsed
                                          ? '已入场'
                                          : '入场码暂不可用',
                                      textAlign: TextAlign.center,
                                      style: style(30, const Color(0xFF5A1E80)),
                                    ),
                                  ),
                          ),
                          SizedBox(height: 10 * unit),
                          if (party.ticketNumber?.isNotEmpty == true)
                            line(party.ticketNumber!),
                          line(party.theme),
                          line(party.storeName),
                        ],
                      ),
                    ),
                    Container(
                      width: 550 * unit,
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
                              child: Text('2、票券权益以活动说明为准，额外消费另行支付。'),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 3),
                              child: Text('3、请在票面活动时段内出示入场码，过期作废。'),
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
