import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LegacyWelcomePage extends StatefulWidget {
  const LegacyWelcomePage({
    super.key,
    required this.onNext,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final VoidCallback onNext;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  State<LegacyWelcomePage> createState() => _LegacyWelcomePageState();
}

class _LegacyWelcomePageState extends State<LegacyWelcomePage> {
  static const _pink = Color(0xFFAD016A);
  static const _palePink = Color(0xFFFBAFDA);

  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const Image(
              key: ValueKey('legacy-welcome-background'),
              image: AssetImage('assets/legacy/home/legacy_login_cover.jpg'),
              fit: BoxFit.cover,
              alignment: Alignment.center,
              excludeFromSemantics: true,
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final pageWidth = constraints.maxWidth;
                  return Stack(
                    children: [
                      Positioned(
                        left: pageWidth * 0.067,
                        top: 44,
                        width: pageWidth * 0.2133,
                        child: Semantics(
                          label: 'King club',
                          image: true,
                          child: const Image(
                            key: ValueKey('legacy-welcome-logo'),
                            image: AssetImage('assets/legacy/home/logo_1.png'),
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                          ),
                        ),
                      ),
                      Positioned(
                        left: pageWidth * 0.10,
                        right: pageWidth * 0.10,
                        bottom: 30,
                        child: _bottomContent(context),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomContent(BuildContext context) {
    const agreementStyle = TextStyle(
      color: Color(0xFFC9B69E),
      fontSize: 15,
      height: 1.35,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              checked: _accepted,
              label: '同意隐私政策和用户协议',
              child: GestureDetector(
                key: const ValueKey('legacy-welcome-consent'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _accepted = !_accepted),
                child: SizedBox.square(
                  dimension: 32,
                  child: Center(
                    child: AnimatedContainer(
                      key: const ValueKey('legacy-welcome-consent-visual'),
                      duration: const Duration(milliseconds: 120),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _accepted ? _palePink : Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _palePink,
                          width: _accepted ? 0.5 : 1.5,
                        ),
                      ),
                      child: _accepted
                          ? const Icon(
                              Icons.check_rounded,
                              key: ValueKey('legacy-welcome-consent-check'),
                              size: 9,
                              color: Colors.black,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: FittedBox(
                key: const ValueKey('legacy-welcome-agreement-line'),
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('我已阅读并同意', style: agreementStyle),
                    _agreementButton('《隐私政策》', widget.onOpenPrivacy),
                    const Text('和', style: agreementStyle),
                    _agreementButton('《用户协议》', widget.onOpenTerms),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 45,
          child: FilledButton(
            key: const ValueKey('legacy-welcome-next'),
            onPressed: _accepted ? widget.onNext : null,
            style: FilledButton.styleFrom(
              backgroundColor: _pink,
              disabledBackgroundColor: _pink.withValues(alpha: 0.27),
              foregroundColor: _palePink,
              disabledForegroundColor: _palePink.withValues(alpha: 0.20),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            child: const Text('NEXT'),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'BUSINESS HOURS',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFC9B69E), fontSize: 13),
        ),
        const Text(
          '20:30-04:00',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFC9B69E), fontSize: 13),
        ),
      ],
    );
  }

  Widget _agreementButton(String label, VoidCallback onPressed) {
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 8),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFC9B69E), width: 0.8),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFC9B69E),
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
