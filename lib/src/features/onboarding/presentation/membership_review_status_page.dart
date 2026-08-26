import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../../../core/mock/mock_runtime.dart';

class MembershipReviewStatusPage extends ConsumerStatefulWidget {
  const MembershipReviewStatusPage({
    super.key,
    required this.flowId,
    required this.onApproved,
    required this.onFixImages,
    required this.onExit,
    required this.onInvalidFlow,
  });

  final String flowId;
  final VoidCallback onApproved;
  final VoidCallback onFixImages;
  final VoidCallback onExit;
  final VoidCallback onInvalidFlow;

  @override
  ConsumerState<MembershipReviewStatusPage> createState() =>
      _MembershipReviewStatusPageState();
}

class _MembershipReviewStatusPageState
    extends ConsumerState<MembershipReviewStatusPage> {
  ReviewStatus _status = ReviewStatus.pending;
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await ref.read(mockRuntimeProvider).completeMockStep();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.read(mockRuntimeProvider).hasOnboardingFlow(widget.flowId)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onInvalidFlow(),
      );
    }
    final presentation = _presentation(_status);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: KingBrandMark(compact: true)),
                  const SizedBox(height: 40),
                  Icon(presentation.icon, size: 72, color: presentation.color),
                  const SizedBox(height: 20),
                  Text(
                    presentation.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    presentation.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: KingColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '最近更新：刚刚',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 28),
                  _primaryAction(),
                  if (_status != ReviewStatus.pending) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _refreshing ? null : _refresh,
                      child: Text(_refreshing ? '正在刷新…' : '刷新状态'),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      title: Text(
                        'UI 测试场景',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        '本地 Mock 专用',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ReviewStatus.values.map((status) {
                              return ChoiceChip(
                                label: Text(_scenarioLabel(status)),
                                selected: _status == status,
                                onSelected: (_) =>
                                    setState(() => _status = status),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: widget.onExit,
                    child: const Text('退出登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _primaryAction() {
    return switch (_status) {
      ReviewStatus.pending => FilledButton(
        onPressed: _refreshing ? null : _refresh,
        child: const Text('刷新状态'),
      ),
      ReviewStatus.changesRequired => FilledButton(
        onPressed: widget.onFixImages,
        child: const Text('补充形象资料'),
      ),
      ReviewStatus.approved => FilledButton(
        onPressed: widget.onApproved,
        child: const Text('进入 KingClub'),
      ),
      ReviewStatus.rejected => const FilledButton(
        onPressed: null,
        child: Text('暂不可重新申请'),
      ),
    };
  }

  _ReviewPresentation _presentation(ReviewStatus status) {
    return switch (status) {
      ReviewStatus.pending => const _ReviewPresentation(
        Icons.schedule_outlined,
        KingColors.warning,
        '会员申请审核中',
        '资料已安全提交，请耐心等待审核结果。',
      ),
      ReviewStatus.changesRequired => const _ReviewPresentation(
        Icons.edit_note_outlined,
        KingColors.info,
        '需要补充资料',
        '请替换不清晰的会员形象资料后重新提交。',
      ),
      ReviewStatus.approved => const _ReviewPresentation(
        Icons.verified_outlined,
        KingColors.success,
        '会员申请已通过',
        '欢迎加入 KingClub，点击下方按钮进入 App。',
      ),
      ReviewStatus.rejected => const _ReviewPresentation(
        Icons.info_outline,
        KingColors.danger,
        '会员申请暂未通过',
        '当前不支持重新提交；正式策略将由权威审核状态提供。',
      ),
    };
  }

  String _scenarioLabel(ReviewStatus status) => switch (status) {
    ReviewStatus.pending => '审核中',
    ReviewStatus.changesRequired => '补资料',
    ReviewStatus.approved => '已通过',
    ReviewStatus.rejected => '未通过',
  };
}

class _ReviewPresentation {
  const _ReviewPresentation(this.icon, this.color, this.title, this.message);

  final IconData icon;
  final Color color;
  final String title;
  final String message;
}
