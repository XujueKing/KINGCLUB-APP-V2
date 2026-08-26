import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';
import 'onboarding_components.dart';

class RealNameAdultVerificationPage extends ConsumerStatefulWidget {
  const RealNameAdultVerificationPage({
    super.key,
    required this.flowId,
    required this.onNext,
    required this.onInvalidFlow,
  });

  final String flowId;
  final VoidCallback onNext;
  final VoidCallback onInvalidFlow;

  @override
  ConsumerState<RealNameAdultVerificationPage> createState() =>
      _RealNameAdultVerificationPageState();
}

class _RealNameAdultVerificationPageState
    extends ConsumerState<RealNameAdultVerificationPage> {
  final _nameController = TextEditingController(text: '测试会员');
  final _identityController = TextEditingController(text: '430102199001011234');
  bool _noticeAccepted = false;
  bool _identityVisible = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _identityController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _identityController.text.trim().length < 15 ||
        !_noticeAccepted) {
      setState(() => _error = '请完整填写合成示例，并阅读信息处理说明');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref.read(mockRuntimeProvider).completeMockStep();
    if (!mounted) return;
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onInvalidFlow(),
      );
    }
    return OnboardingScaffold(
      step: 1,
      title: '实名与成年核验',
      subtitle: '用于确认本人身份及年满 18 周岁。成年结论只由权威核验结果决定。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const KingStatusCard(
            icon: Icons.science_outlined,
            title: '合成数据演示',
            message: '请勿输入真实姓名或证件号码；本页不会保存或上传内容。',
            color: KingColors.info,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            enabled: !_submitting,
            decoration: const InputDecoration(labelText: '姓名'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _identityController,
            enabled: !_submitting,
            obscureText: !_identityVisible,
            decoration: InputDecoration(
              labelText: '证件号码',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _identityVisible = !_identityVisible),
                icon: Icon(
                  _identityVisible ? Icons.visibility_off : Icons.visibility,
                ),
                tooltip: _identityVisible ? '隐藏证件号码' : '临时显示证件号码',
              ),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _noticeAccepted,
            onChanged: _submitting
                ? null
                : (value) => setState(() {
                    _noticeAccepted = value ?? false;
                    _error = null;
                  }),
            title: const Text('我已阅读实名信息处理说明'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: KingColors.danger)),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('开始 Fake 核验'),
          ),
        ],
      ),
    );
  }
}
