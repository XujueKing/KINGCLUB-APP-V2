import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'legacy_club_components.dart';

class AaPositioningCardPage extends StatefulWidget {
  const AaPositioningCardPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AaPositioningCardPage> createState() => _AaPositioningCardPageState();
}

class _AaPositioningCardPageState extends State<AaPositioningCardPage>
    with WidgetsBindingObserver {
  Timer? _timer;
  int _tokenVersion = 1;
  bool _privacyCovered = false;

  String get _token =>
      'KC-AA-POSITIONING-20260827-888-K24500000299-V$_tokenVersion';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_privacyCovered) {
        setState(() => _tokenVersion += 1);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final covered =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden;
    if (!mounted || covered == _privacyCovered) return;
    setState(() {
      _privacyCovered = covered;
      if (!covered) _tokenVersion += 1;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12020C),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.58),
            radius: .92,
            colors: [Color(0xFF470F24), Color(0xFF12020C)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 6,
                      child: IconButton(
                        tooltip: '返回',
                        onPressed: widget.onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: legacyPink,
                          size: 22,
                        ),
                      ),
                    ),
                    const Text(
                      'POSITIONING CARD',
                      style: TextStyle(
                        color: legacyPink,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        letterSpacing: .4,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(17, 14, 17, 34),
                  children: [
                    _buildPositioningCard(),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 36),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STORAGE INSTRUCTIONS:',
                            style: TextStyle(
                              color: Color(0x99FBAFDA),
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '1、着装邋遢，大量纹身外露会被拒绝进入；',
                            style: _instructionStyle,
                          ),
                          Text(
                            '2、套餐内无需再付费，套餐外点单需另付费；',
                            style: _instructionStyle,
                          ),
                          Text(
                            '3、此入场码只限当天使用，使用过后即作废；',
                            style: _instructionStyle,
                          ),
                        ],
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
  }

  Widget _buildPositioningCard() {
    return Container(
      key: const ValueKey('aa-positioning-card-page'),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const RadialGradient(
          center: Alignment(1, 1),
          radius: 1.15,
          colors: [Color(0xFFAD016A), Color(0xFF5A1E80)],
        ),
      ),
      child: Column(
        children: [
          const Text(
            '888',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'serif',
              fontSize: 70,
              height: .95,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'POSITIONING CARD',
            style: TextStyle(color: legacyPink, fontSize: 14),
          ),
          const SizedBox(height: 5),
          const Text(
            '2026-08-27 20:30-04:00',
            style: TextStyle(color: legacyPink, fontSize: 13),
          ),
          const SizedBox(height: 18),
          const _AaSeatGrid(boxSize: 36, iconHeight: 22),
          const SizedBox(height: 27),
          Semantics(
            label: _privacyCovered ? '入场二维码已遮盖' : '888 卡座动态入场二维码',
            image: true,
            child: Container(
              width: 228,
              height: 228,
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: _privacyCovered
                  ? const Center(
                      child: Icon(
                        Icons.visibility_off_rounded,
                        color: Color(0xFF5A1E80),
                        size: 52,
                      ),
                    )
                  : QrImageView(
                      key: ValueKey('aa-positioning-qr-v$_tokenVersion'),
                      data: _token,
                      version: QrVersions.auto,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                      embeddedImage: const AssetImage(
                        'assets/legacy/aa/kingLogo.png',
                      ),
                      embeddedImageStyle: const QrEmbeddedImageStyle(
                        size: Size(46, 46),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'K24500000299',
            style: TextStyle(color: legacyPink, fontSize: 13),
          ),
          const SizedBox(height: 5),
          const Text(
            '3880卡座套餐',
            style: TextStyle(color: legacyPink, fontSize: 13),
          ),
          const SizedBox(height: 5),
          const Text(
            '单人票价：388元',
            style: TextStyle(color: legacyPink, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class AaLegacyConfirmedReservationCard extends StatelessWidget {
  const AaLegacyConfirmedReservationCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '888 卡座，08.27 21:00-04:00，3880卡座套餐，388元每人，查看定位凭证',
      child: InkWell(
        key: const ValueKey('aa-confirmed-positioning-card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 130,
          padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const RadialGradient(
              center: Alignment(1, 1),
              radius: 1.2,
              colors: [Color(0xFFAD016A), Color(0xFF5A1E80)],
            ),
          ),
          child: Row(
            children: [
              const Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '888',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'serif',
                        fontSize: 56,
                        height: .86,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '08.27 21:00-04:00',
                      style: TextStyle(color: legacyPink, fontSize: 12),
                    ),
                    SizedBox(height: 5),
                    Image(
                      image: AssetImage('assets/legacy/aa/positioningCard.png'),
                      width: 138,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AaSeatGrid(boxSize: 21, iconHeight: 13),
                    SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '3880卡座套餐',
                              style: TextStyle(color: legacyPink, fontSize: 12),
                            ),
                            SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '￥388',
                                    style: TextStyle(
                                      color: legacyPink,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '/人',
                                    style: TextStyle(
                                      color: legacyPink,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 9),
                        Image(
                          image: AssetImage('assets/legacy/aa/qrcode2.png'),
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
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
    );
  }
}

class _AaSeatGrid extends StatelessWidget {
  const _AaSeatGrid({required this.boxSize, required this.iconHeight});

  final double boxSize;
  final double iconHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (boxSize * 5) + 8,
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: List.generate(10, (index) {
          final selected = index == 0;
          final male = index.isEven;
          return Container(
            width: boxSize,
            height: boxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFFBAFDA)
                  : const Color(0x55FBAFDA),
              borderRadius: BorderRadius.circular(1),
            ),
            child: Image.asset(
              selected
                  ? 'assets/legacy/aa/man2.png'
                  : male
                  ? 'assets/legacy/aa/man.png'
                  : 'assets/legacy/aa/woman.png',
              height: iconHeight,
              fit: BoxFit.contain,
              opacity: AlwaysStoppedAnimation(selected ? 1 : .55),
            ),
          );
        }),
      ),
    );
  }
}

const _instructionStyle = TextStyle(
  color: Color(0x88FBAFDA),
  fontSize: 12,
  height: 1.75,
);
