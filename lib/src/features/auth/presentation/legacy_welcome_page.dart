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
                        bottom: 26,
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
      color: Color(0xFFF2D7E5),
      fontSize: 14,
      height: 1.35,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: 32,
              child: Checkbox(
                key: const ValueKey('legacy-welcome-consent'),
                value: _accepted,
                shape: const CircleBorder(),
                side: BorderSide.none,
                fillColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? _palePink
                      : const Color(0x66FBAFDA),
                ),
                checkColor: const Color(0xFF541033),
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('我已阅读并同意', style: agreementStyle),
                  _agreementButton('《隐私政策》', widget.onOpenPrivacy),
                  const Text('和', style: agreementStyle),
                  _agreementButton('《用户协议》', widget.onOpenTerms),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 50,
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
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('NEXT'),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'BUSINESS HOURS',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFE9CAD9), fontSize: 14),
        ),
        const SizedBox(height: 3),
        const Text(
          '20:30-04:00',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFD7B6C7), fontSize: 14),
        ),
      ],
    );
  }

  Widget _agreementButton(String label, VoidCallback onPressed) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: const Color(0xFFF2D7E5),
        textStyle: const TextStyle(
          fontSize: 14,
          height: 1.35,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFFF2D7E5),
        ),
      ),
      child: Text(label),
    );
  }
}
