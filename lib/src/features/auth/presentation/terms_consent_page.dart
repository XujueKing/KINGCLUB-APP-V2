import 'package:flutter/material.dart';

import '../../../core/design_system/king_theme.dart';

enum AgreementKind { terms, privacy }

class TermsConsentPage extends StatefulWidget {
  const TermsConsentPage({
    super.key,
    required this.initialAgreement,
    required this.onClose,
  });

  final AgreementKind initialAgreement;
  final VoidCallback onClose;

  @override
  State<TermsConsentPage> createState() => _TermsConsentPageState();
}

class _TermsConsentPageState extends State<TermsConsentPage> {
  late AgreementKind _selected = widget.initialAgreement;

  @override
  Widget build(BuildContext context) {
    final isTerms = _selected == AgreementKind.terms;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onClose,
          icon: const Icon(Icons.close),
        ),
        title: const Text('协议与隐私'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<AgreementKind>(
                    segments: const [
                      ButtonSegment(
                        value: AgreementKind.terms,
                        label: Text('用户协议 vMock'),
                      ),
                      ButtonSegment(
                        value: AgreementKind.privacy,
                        label: Text('隐私政策 vMock'),
                      ),
                    ],
                    selected: {_selected},
                    onSelectionChanged: (value) =>
                        setState(() => _selected = value.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '发布日期：2026-08-26',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: KingColors.surface,
                        border: Border.all(color: KingColors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          isTerms ? _mockTerms : _mockPrivacy,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '以上为 UI Mock 占位正文，不构成正式法律文本，也不会写入同意记录。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: KingColors.warning),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _mockTerms = '''KingClub 用户协议（Mock）

一、说明
本页面用于验证协议阅读、标签切换、动态字体和返回流程。

二、会员服务
正式权利义务、会员规则和服务边界将在法务文本批准后展示。

三、账户安全
请妥善保护账户信息，不要向他人透露验证码。''';

const _mockPrivacy = '''KingClub 隐私政策（Mock）

一、说明
本页面仅使用虚构内容验证 UI，不采集或上传个人信息。

二、最小化原则
正式版本将说明数据类型、使用目的、保存期限和用户权利。

三、系统权限
相机、相册、通知与定位仅在相关功能中按需申请。''';
