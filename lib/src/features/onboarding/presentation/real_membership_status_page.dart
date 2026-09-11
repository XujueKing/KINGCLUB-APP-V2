import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_theme.dart';
import '../data/real_identity_repository.dart';

class RealMembershipStatusPage extends ConsumerStatefulWidget {
  const RealMembershipStatusPage({
    super.key,
    required this.onApproved,
    required this.onIdentity,
    required this.onBack,
    this.onImages,
  });
  final VoidCallback onApproved;
  final VoidCallback onIdentity;
  final VoidCallback onBack;
  final VoidCallback? onImages;
  @override
  ConsumerState<RealMembershipStatusPage> createState() =>
      _RealMembershipStatusPageState();
}

class _RealMembershipStatusPageState
    extends ConsumerState<RealMembershipStatusPage> {
  bool _loading = false;
  String? _error;
  num? _score;
  bool _scoreLoading = true;
  String? _scoreError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadScore);
  }

  Future<void> _loadScore() async {
    final member = ref.read(authenticatedMemberProvider);
    if (member == null ||
        member.accountStatus != 'active' ||
        member.membershipStatus != 'active') {
      if (mounted) setState(() => _scoreLoading = false);
      return;
    }
    try {
      final status = await ref
          .read(realIdentityRepositoryProvider)
          .appearanceStatus();
      final result = status['result'];
      final value = result is Map ? result['score'] : null;
      if (mounted) {
        setState(() {
          _score = value is num && value.isFinite && value >= 0 && value <= 100
              ? value
              : null;
          _scoreError = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scoreError = '评分暂未加载，您可以稍后刷新');
    } finally {
      if (mounted) setState(() => _scoreLoading = false);
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repository = ref.read(authRepositoryProvider);
      if (repository is! RealAuthRepository) {
        throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
      }
      final state = await repository.refreshMembership();
      if (!mounted) return;
      if (state.canEnterApp) {
        widget.onApproved();
      } else if (state.needsIdentity) {
        widget.onIdentity();
      } else if (state.needsImages) {
        widget.onImages?.call();
      } else {
        await _loadScore();
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = '暂时无法获取会员状态，请稍后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 740;
    final member = ref.watch(authenticatedMemberProvider);
    final restricted =
        member == null ||
        member.accountStatus != 'active' ||
        member.membershipStatus != 'active';
    final message = restricted
        ? '会员状态暂不可用，请重新登录或联系客服'
        : switch (member.registrationStatus) {
            'pending_review' => '资料已收到，正在等待审核',
            'photos_required' => '实名认证已通过，请继续完善会员形象照片',
            'changes_required' => '会员资料需要补充，请按审核要求重新提交',
            'rejected' => '本次申请暂未通过，可联系营销了解详情',
            'approved' => '注册已通过，请刷新进入首页',
            _ => '暂时无法确认注册进度，请刷新重试',
          };
    return Scaffold(
      appBar: AppBar(
        leadingWidth: KingBackButton.leftOffset(context) + 48,
        toolbarHeight: 56,
        title: const Text('会员注册状态'),
        leading: Padding(
          padding: EdgeInsets.only(
            left: KingBackButton.leftOffset(context),
            top: 4,
            bottom: 4,
          ),
          child: KingBackButton(onPressed: widget.onBack),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: KingBackButton.contentWidth(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: compact ? 12 : 20,
                      bottom: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          !restricted && member.registrationStatus == 'approved'
                              ? '欢迎加入 KINGCLUB'
                              : '感谢您的申请',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          style: const TextStyle(
                            color: KingColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        if (!restricted) ...[
                          SizedBox(height: compact ? 16 : 20),
                          Container(
                            padding: EdgeInsets.all(compact ? 12 : 16),
                            decoration: BoxDecoration(
                              color: KingColors.surface,
                              border: Border.all(color: KingColors.border),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  '形象参考评分',
                                  style: TextStyle(
                                    color: KingColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _score == null
                                      ? '—'
                                      : _score!.toStringAsFixed(0),
                                  key: const ValueKey(
                                    'membership-appearance-score',
                                  ),
                                  style: TextStyle(
                                    fontSize: compact ? 40 : 46,
                                    fontWeight: FontWeight.w300,
                                    color: KingColors.brandStrong,
                                  ),
                                ),
                                Text(
                                  _scoreLoading
                                      ? '正在读取评分'
                                      : _scoreError ??
                                            (_score == null
                                                ? '评分结果待确认'
                                                : '三张照片平均分 · 满分 100'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: KingColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '评分仅供本次申请参考，不代表个人价值。最终结果以会员审核为准。',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: KingColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: compact ? 16 : 20),
                          const Text(
                            '希望更快了解审核进度？',
                            style: TextStyle(
                              fontSize: 14,
                              color: KingColors.brandStrong,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '联系营销人员，协助跟进审核或补充资料。',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: KingColors.textSecondary,
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: KingColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: FilledButton(
                    onPressed: _loading ? null : _refresh,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(45),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(_loading ? '正在刷新' : '刷新状态'),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  children: [
                    if (!restricted &&
                        member.registrationStatus == 'pending_review')
                      TextButton(
                        onPressed: widget.onImages,
                        child: const Text('更换形象照片'),
                      ),
                    TextButton(
                      onPressed: widget.onBack,
                      child: const Text('返回登录'),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
