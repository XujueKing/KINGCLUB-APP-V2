import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import 'legacy_legal_content.dart';

enum AboutLegalScenario {
  catalog,
  offlineCached,
  offlineExpired,
  invalidRef,
  loadingError,
  sessionInvalid,
}

class AboutLegalPage extends StatefulWidget {
  const AboutLegalPage({
    super.key,
    this.initialScenario = AboutLegalScenario.catalog,
    this.initialDocumentIndex,
    this.onBack,
    this.onSessionResetRequested,
  });

  final AboutLegalScenario initialScenario;
  final int? initialDocumentIndex;
  final VoidCallback? onBack;
  final VoidCallback? onSessionResetRequested;

  @override
  State<AboutLegalPage> createState() => _AboutLegalPageState();
}

class _LegalDocument {
  const _LegalDocument({required this.appBarTitle, required this.blocks});
  final String appBarTitle;
  final List<LegacyLegalBlock> blocks;
}

class _AboutLegalPageState extends State<AboutLegalPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFFAAA096);
  _LegalDocument? _document;
  late AboutLegalScenario _scenario;

  static const _documents = [
    _LegalDocument(
      appBarTitle: 'KINGBAR用户协议',
      blocks: legacyUserAgreementBlocks,
    ),
    _LegalDocument(appBarTitle: 'KINGBAR隐私政策', blocks: legacyPrivacyBlocks),
  ];

  @override
  void initState() {
    super.initState();
    _scenario = widget.initialScenario;
    final index = widget.initialDocumentIndex;
    if (index != null && index >= 0 && index < _documents.length) {
      _document = _documents[index];
    } else if (index != null) {
      _scenario = AboutLegalScenario.invalidRef;
    }
    if (_scenario == AboutLegalScenario.sessionInvalid) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showSessionInvalid(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _document == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _document = null);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: DecoratedBox(
          decoration: BoxDecoration(
            color: _document == null ? null : Colors.black,
            gradient: _document == null
                ? const RadialGradient(
                    center: Alignment(0, -0.62),
                    radius: 0.94,
                    colors: [
                      Color(0xEF252018),
                      Color(0xFF0B0907),
                      Colors.black,
                    ],
                    stops: [0, 0.48, 1],
                  )
                : null,
          ),
          child: SafeArea(
            child: Column(
              children: [
                _AboutHeader(
                  title: _document?.appBarTitle ?? '关于KINGBAR',
                  onBack: _handleBack,
                  onTitleLongPress: _showScenarioPanel,
                ),
                Expanded(
                  child: _document != null
                      ? _reader(_document!)
                      : switch (_scenario) {
                          AboutLegalScenario.offlineExpired => _failureState(
                            key: 'offline-expired',
                            icon: Icons.cloud_off_outlined,
                            title: '离线缓存已过期',
                            detail: '为避免展示失效法律文本，请联网后重新获取权威目录。',
                          ),
                          AboutLegalScenario.invalidRef => _failureState(
                            key: 'invalid-ref',
                            icon: Icons.link_off_outlined,
                            title: '文档引用无效',
                            detail: '该文档不在当前可见的权威目录中，已拒绝打开。',
                          ),
                          AboutLegalScenario.loadingError => _failureState(
                            key: 'loading-error',
                            icon: Icons.error_outline,
                            title: '法律文档暂时无法加载',
                            detail: '必需文档不会以空白正文代替，请稍后重试。',
                          ),
                          _ => _catalog(),
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _catalog() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = math.min(
          constraints.maxWidth,
          MediaQuery.sizeOf(context).width,
        );
        final scale = viewportWidth / 750;
        final contentWidth = math.min(600 * scale, viewportWidth - 48);

        return ListView(
          key: const ValueKey('about-legal-catalog'),
          padding: EdgeInsets.only(bottom: 70 * scale),
          children: [
            if (_scenario == AboutLegalScenario.offlineCached) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 50 * scale),
                child: const _AboutNotice(
                  key: ValueKey('about-offline-cached'),
                  icon: Icons.offline_pin_outlined,
                  text: '当前离线，展示已校验的可信缓存。正文将标记版本与生效日期。',
                ),
              ),
              SizedBox(height: 22 * scale),
            ],
            SizedBox(height: 150 * scale),
            Center(
              child: Image.asset(
                'assets/legacy/home/logo_2.png',
                width: 220 * scale,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            SizedBox(height: 40 * scale),
            Center(
              child: Image.asset(
                'assets/legacy/profile/klztext.png',
                width: 350 * scale,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
            SizedBox(height: 60 * scale),
            Center(
              child: SizedBox(
                width: contentWidth,
                child: Text(
                  '感谢您使用KINGBAR酒吧预定APP，KINGBAR预定APP是为广大会员提供全面服务的应用服务工具。',
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    color: _gold.withValues(alpha: .8),
                    fontSize: 28 * scale,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            SizedBox(height: 40 * scale),
            Center(
              child: SizedBox(
                width: contentWidth,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '会员需要遵守以下',
                      style: TextStyle(
                        color: _gold.withValues(alpha: .8),
                        fontSize: 28 * scale,
                      ),
                    ),
                    _legalLink(1, '《隐私政策》', scale),
                    Text(
                      '和',
                      style: TextStyle(
                        color: _gold.withValues(alpha: .8),
                        fontSize: 28 * scale,
                      ),
                    ),
                    _legalLink(0, '《用户协议》', scale),
                  ],
                ),
              ),
            ),
            SizedBox(height: 52 * scale),
            for (final line in const [
              '技术支持：548627@qq.com',
              '2025 版本号：1.1.17',
              '软件著作权认证证书：软著认000255367号',
              '电子版权认证证书：电子认证第 R20250000054907 号',
              'ICP备案号：湘ICP备2025115786号-2A（APP）',
              'ICP备案号：湘ICP备2025115786号-1X（小程序）',
              '软件开发商：湖南领美网络科技有限公司',
            ]) ...[
              Center(
                child: SizedBox(
                  width: viewportWidth - 36,
                  child: Text(
                    line,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _gold.withValues(alpha: .8),
                      fontSize: 26 * scale,
                      height: 1.45,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10 * scale),
            ],
          ],
        );
      },
    );
  }

  Widget _legalLink(int index, String label, double scale) {
    return InkWell(
      key: ValueKey('about-legal-document-$index'),
      onTap: () => setState(() => _document = _documents[index]),
      child: Text(
        label,
        style: TextStyle(
          color: const Color(0xFFA2D0FF),
          fontSize: 28 * scale,
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFFA2D0FF),
        ),
      ),
    );
  }

  Widget _reader(_LegalDocument document) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = math.min(
          constraints.maxWidth,
          MediaQuery.sizeOf(context).width,
        );
        final scale = viewportWidth / 750;
        final contentWidth = math.min(650 * scale, viewportWidth - 36);
        return Column(
          children: [
            Expanded(
              child: ListView(
                key: ValueKey('about-legal-reader-${document.appBarTitle}'),
                children: [
                  if (_scenario == AboutLegalScenario.offlineCached) ...[
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        50 * scale,
                        20 * scale,
                        50 * scale,
                        0,
                      ),
                      child: const _AboutNotice(
                        key: ValueKey('about-reader-offline-cached'),
                        icon: Icons.offline_pin_outlined,
                        text: '离线缓存 · 已校验版本',
                      ),
                    ),
                  ],
                  Center(
                    child: SizedBox(
                      width: contentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final block in document.blocks)
                            _legacyLegalBlock(block, scale),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 100 * scale),
          ],
        );
      },
    );
  }

  Widget _legacyLegalBlock(LegacyLegalBlock block, double scale) {
    final isMainTitle = block.type == 3;
    final isSectionTitle = block.type == 1;
    final isEmphasis = block.type == 8;
    final text = isMainTitle ? '《${block.text}》' : block.text;
    return Padding(
      padding: EdgeInsets.only(
        top:
            (isMainTitle
                ? 35
                : isSectionTitle
                ? 45
                : 20) *
            scale,
        bottom:
            (isMainTitle
                ? 40
                : isSectionTitle
                ? 20
                : 20) *
            scale,
      ),
      child: Text(
        text,
        textAlign: isMainTitle ? TextAlign.center : TextAlign.start,
        style: TextStyle(
          color: isMainTitle || isSectionTitle
              ? Colors.white
              : const Color(0xFFCCCCCC),
          fontSize:
              (isMainTitle
                  ? 40
                  : isSectionTitle
                  ? 35
                  : 30) *
              scale,
          height: isMainTitle ? 1.18 : 1.34,
          fontWeight: isMainTitle || isEmphasis
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
    );
  }

  void _handleBack() {
    if (_document != null) {
      setState(() => _document = null);
    } else {
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.maybePop(context);
      }
    }
  }

  Widget _failureState({
    required String key,
    required IconData icon,
    required String title,
    required String detail,
  }) {
    return Center(
      key: ValueKey('about-$key'),
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _gold, size: 66),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 26),
            OutlinedButton(
              key: const ValueKey('about-retry'),
              onPressed: () => setState(() {
                _scenario = AboutLegalScenario.catalog;
                _document = null;
              }),
              child: const Text('重新加载'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScenarioPanel() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF171411),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
          children: [
            const Text(
              '关于与法律 UI Mock 场景',
              style: TextStyle(
                color: _gold,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final scenario in AboutLegalScenario.values)
              ListTile(
                key: ValueKey('about-scenario-${scenario.name}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _scenarioLabel(scenario),
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: scenario == _scenario
                    ? const Icon(Icons.check, color: _gold)
                    : null,
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() {
                    _scenario = scenario;
                    _document = null;
                  });
                  if (scenario == AboutLegalScenario.sessionInvalid) {
                    _showSessionInvalid();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  String _scenarioLabel(AboutLegalScenario scenario) => switch (scenario) {
    AboutLegalScenario.catalog => '权威目录',
    AboutLegalScenario.offlineCached => '离线可信缓存',
    AboutLegalScenario.offlineExpired => '离线缓存过期',
    AboutLegalScenario.invalidRef => '无效 DocumentRef',
    AboutLegalScenario.loadingError => '目录加载失败',
    AboutLegalScenario.sessionInvalid => '会话失效',
  };

  Future<void> _showSessionInvalid() async {
    _document = null;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('about-session-dialog'),
        title: const Text('登录状态已失效'),
        content: const Text('页面内的临时文档引用已清理，请重新登录。'),
        actions: [
          FilledButton(
            key: const ValueKey('about-session-confirm'),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
    if (mounted) widget.onSessionResetRequested?.call();
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({
    required this.title,
    required this.onBack,
    required this.onTitleLongPress,
  });
  final String title;
  final VoidCallback onBack;
  final VoidCallback onTitleLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: KingBackButton.leftOffset(context),
            top: KingBackButton.safeAreaOffset.dy,
            child: KingBackButton(
              key: const ValueKey('about-legal-back'),
              onPressed: onBack,
            ),
          ),
          GestureDetector(
            key: const ValueKey('about-legal-title'),
            onLongPress: onTitleLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: KingBackButton.contentWidth(context) - 70,
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFC9B69E),
                  fontSize: 19,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutNotice extends StatelessWidget {
  const _AboutNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF171411),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4A4035)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFC9B69E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFAAA096),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
