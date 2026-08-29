import 'package:flutter/material.dart';

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
  const _LegalDocument({
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.sections,
  });
  final String title;
  final String version;
  final String effectiveDate;
  final List<(String, String)> sections;
}

class _AboutLegalPageState extends State<AboutLegalPage> {
  static const _gold = Color(0xFFC9B69E);
  static const _muted = Color(0xFFAAA096);
  _LegalDocument? _document;
  late AboutLegalScenario _scenario;

  static const _documents = [
    _LegalDocument(
      title: 'KING CLUB 会员服务协议',
      version: '预发布版',
      effectiveDate: '待权威目录确认',
      sections: [
        ('引言', '欢迎使用 KingClub。协议内容将在正式发布前完成审核并更新。'),
        ('一、服务范围', 'KingClub 为成年会员提供同城社交、到店活动与相关会员服务。正式范围以发布时权威协议为准。'),
        ('二、账号与会员', '用户应妥善保管账号凭据，并遵守平台规则。正式权利义务以权威 DocumentRef 为准。'),
      ],
    ),
    _LegalDocument(
      title: 'KingClub 隐私政策',
      version: '预发布版',
      effectiveDate: '待权威目录确认',
      sections: [
        ('一、信息处理说明', '隐私政策将在正式发布前说明信息收集、使用、保存与保护规则。'),
        ('二、你的权利', '正式版本将说明访问、更正、删除、撤回授权和注销等权利及操作渠道。'),
        ('三、联系我们', '正式联系方式将在发布前由权威文档目录提供。'),
      ],
    ),
    _LegalDocument(
      title: '第三方 SDK 与权限说明',
      version: '预发布版',
      effectiveDate: '待权威目录确认',
      sections: [
        ('说明', '正式清单将列出 SDK 名称、开发者、使用目的、数据类型、权限与隐私政策链接。'),
        ('发布说明', '正式清单将在相关能力启用前完成更新并向用户公开。'),
      ],
    ),
    _LegalDocument(
      title: '账号注销与数据处理说明',
      version: '预发布版',
      effectiveDate: '待权威目录确认',
      sections: [
        ('注销范围', '仅注销 KingClub 会员和业务资料，不注销物业共享身份或物业账号。'),
        ('依法留存', '交易、安全和争议处理所需数据可能依法保留至规定期限。'),
        ('不可恢复', '正式注销完成后，不能通过客户端恢复已删除的 KingClub 资料和权益。'),
      ],
    ),
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
        body: SafeArea(
          child: Column(
            children: [
              _AboutHeader(
                title: _document?.title ?? '关于 KingClub',
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
    );
  }

  Widget _catalog() {
    return ListView(
      key: const ValueKey('about-legal-catalog'),
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
      children: [
        if (_scenario == AboutLegalScenario.offlineCached) ...[
          const _AboutNotice(
            key: ValueKey('about-offline-cached'),
            icon: Icons.offline_pin_outlined,
            text: '当前离线，展示已校验的可信缓存。正文将标记版本与生效日期。',
          ),
          const SizedBox(height: 22),
        ],
        Center(
          child: Image.asset(
            'assets/legacy/home/logo_2.png',
            width: 126,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'KingClub',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'V2 1.0.0 (1)',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 28),
        const Text(
          '感谢使用 KingClub。会员需阅读并遵守以下协议、政策及数据处理说明。',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.6, fontSize: 13),
        ),
        const SizedBox(height: 28),
        ...List.generate(
          _documents.length,
          (index) => InkWell(
            key: ValueKey('about-legal-document-$index'),
            onTap: () => setState(() => _document = _documents[index]),
            child: Container(
              constraints: const BoxConstraints(minHeight: 60),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x22C9B69E))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _documents[index].title,
                      style: const TextStyle(color: _gold, fontSize: 15),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _muted),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          '技术支持：548627@qq.com',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        const Text(
          '软件开发商：湖南领美网络科技有限公司',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        const Text(
          '备案与版权信息发布前复核',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6A6259), fontSize: 11),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _reader(_LegalDocument document) {
    return ListView(
      key: ValueKey('about-legal-reader-${document.title}'),
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 52),
      children: [
        if (_scenario == AboutLegalScenario.offlineCached) ...[
          const _AboutNotice(
            key: ValueKey('about-reader-offline-cached'),
            icon: Icons.offline_pin_outlined,
            text: '离线缓存 · 已校验版本',
          ),
          const SizedBox(height: 20),
        ],
        Text(
          '《${document.title}》',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '版本：${document.version}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 5),
        Text(
          '生效日期：${document.effectiveDate}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 28),
        ...document.sections.expand(
          (section) => [
            Text(
              section.$1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.$2,
              style: const TextStyle(
                color: Color(0xFFCCCCCC),
                fontSize: 15,
                height: 1.75,
              ),
            ),
            const SizedBox(height: 26),
          ],
        ),
        const Text(
          '文档内容以正式发布版本为准。',
          style: TextStyle(color: Color(0xFF6A6259), fontSize: 12),
        ),
      ],
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
      height: 62,
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Color(0xFFC9B69E),
              size: 21,
            ),
          ),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('about-legal-title'),
              onLongPress: onTitleLongPress,
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC9B69E),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
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
