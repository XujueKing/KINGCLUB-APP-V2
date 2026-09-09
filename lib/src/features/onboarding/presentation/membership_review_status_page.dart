import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  late ReviewStatus _status;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _status =
        ref
            .read(mockRuntimeProvider)
            .onboardingSnapshot(widget.flowId)
            ?.reviewStatus ??
        ReviewStatus.pending;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    final snapshot = await ref
        .read(mockRuntimeProvider)
        .refreshOnboarding(widget.flowId);
    if (!mounted) return;
    if (snapshot == null) {
      widget.onInvalidFlow();
      return;
    }
    setState(() {
      _status = snapshot.reviewStatus;
      _refreshing = false;
    });
  }

  Future<void> _enterApp() async {
    setState(() => _refreshing = true);
    final snapshot = await ref
        .read(mockRuntimeProvider)
        .refreshOnboarding(widget.flowId);
    if (!mounted) return;
    if (snapshot?.reviewStatus == ReviewStatus.approved &&
        ref.read(mockRuntimeProvider).canEnterApp(widget.flowId)) {
      setState(() => _refreshing = false);
      widget.onApproved();
      return;
    }
    if (snapshot == null) {
      widget.onInvalidFlow();
      return;
    }
    setState(() {
      _status = snapshot.reviewStatus;
      _refreshing = false;
    });
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                const verticalPadding = 72.0;
                final minimumContentHeight =
                    (constraints.maxHeight - verticalPadding).clamp(
                      0.0,
                      double.infinity,
                    );
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minimumContentHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Center(
                              child: _reviewContent(context, presentation),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          _scenarioPanel(context),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewContent(
    BuildContext context,
    _ReviewPresentation presentation,
  ) {
    return Column(
      key: const ValueKey('membership-review-content'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (_status == ReviewStatus.appearanceReview) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey('membership-review-reupload'),
            onPressed: _refreshing ? null : widget.onFixImages,
            style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
            child: const Text('重新上传照片'),
          ),
        ],
        if (_status != ReviewStatus.approved) ...[
          if (_status != ReviewStatus.pending &&
              _status != ReviewStatus.appearanceReview) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _refreshing ? null : _refresh,
              style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
              child: Text(_refreshing ? '正在刷新…' : '刷新状态'),
            ),
          ],
          const SizedBox(height: 24),
          TextButton(onPressed: widget.onExit, child: const Text('退出登录')),
        ],
      ],
    );
  }

  Widget _scenarioPanel(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text('UI 测试场景', style: Theme.of(context).textTheme.bodyMedium),
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
                  onSelected: (_) {
                    ref
                        .read(mockRuntimeProvider)
                        .setReviewFixture(widget.flowId, status);
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(content: Text('服务端测试状态已更新，请刷新查看')),
                      );
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _refreshing ? null : _refresh,
              icon: const Icon(Icons.sync_rounded),
              label: Text(_refreshing ? '正在读取…' : '应用并刷新测试状态'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryAction() {
    return switch (_status) {
      ReviewStatus.pending => FilledButton(
        onPressed: _refreshing ? null : _refresh,
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        child: const Text('刷新状态'),
      ),
      ReviewStatus.appearanceReview => FilledButton(
        onPressed: _refreshing ? null : _refresh,
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        child: Text(_refreshing ? '正在刷新…' : '刷新审核状态'),
      ),
      ReviewStatus.changesRequired => FilledButton(
        onPressed: widget.onFixImages,
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        child: const Text('补充形象资料'),
      ),
      ReviewStatus.approved => FilledButton(
        onPressed: _refreshing ? null : _enterApp,
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        child: Text(_refreshing ? '正在确认…' : '进入 KingClub'),
      ),
      ReviewStatus.rejected => FilledButton(
        onPressed: null,
        style: FilledButton.styleFrom(shape: const StadiumBorder()),
        child: const Text('暂不可重新申请'),
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
      ReviewStatus.appearanceReview => const _ReviewPresentation(
        Icons.manage_search_outlined,
        KingColors.warning,
        '颜值分数不够，等待审核',
        '资料已进入人工审核。你可以刷新审核状态，或重新上传两张近期清晰照片。',
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
        '本次申请暂未通过，重新申请时间请以页面后续通知为准。',
      ),
    };
  }

  String _scenarioLabel(ReviewStatus status) => switch (status) {
    ReviewStatus.pending => '审核中',
    ReviewStatus.appearanceReview => '颜值待审',
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
