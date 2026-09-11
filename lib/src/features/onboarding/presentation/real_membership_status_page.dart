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
        member.membershipStatus != 'active' ||
        ['rejected', 'blocked'].contains(member.registrationStatus)) {
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
        // Membership refresh publishes the approved state; the member chooses
        // when to leave the welcome screen using the primary action.
        if (_score == null || _scoreError != null) await _loadScore();
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
    final media = MediaQuery.of(context);
    final usableHeight = media.size.height - media.padding.vertical - 56;
    final textScale = media.textScaler.scale(14) / 14;
    final narrowScreenFactor = (360 / media.size.width).clamp(1.0, 1.25);
    final expandReviewReason =
        usableHeight >= 700 * textScale * narrowScreenFactor;
    final member = ref.watch(authenticatedMemberProvider);
    final approved = member?.canEnterApp == true;
    final blocked = member?.registrationStatus == 'blocked';
    final rejected = member?.registrationStatus == 'rejected';
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
            'rejected' => '本次申请暂未符合俱乐部入会标准。',
            'blocked' => '您的入会资格已被限制，更换手机号或照片不会解除此限制。',
            'approved' => '您的会员申请已通过，开启 KINGCLUB 之旅。',
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
                          approved
                              ? '欢迎加入 KINGCLUB'
                              : blocked
                              ? '入会资格已受限'
                              : rejected
                              ? '本次申请未通过'
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
                        if (!restricted && (blocked || rejected)) ...[
                          const SizedBox(height: 16),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            iconColor: KingColors.brandStrong,
                            collapsedIconColor: KingColors.brandStrong,
                            title: const Text(
                              '查看具体原因',
                              style: TextStyle(
                                fontSize: 14,
                                color: KingColors.brandStrong,
                              ),
                            ),
                            children: [
                              Text(
                                member.publicDecisionReason
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? member.publicDecisionReason!.trim()
                                    : '暂无详细说明。如需了解详情或申请复核，请联系俱乐部工作人员。',
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: KingColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            '如对决定有疑问，可联系俱乐部工作人员申请复核。',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: KingColors.textSecondary,
                            ),
                          ),
                        ],
                        if (!restricted && !blocked && !rejected) ...[
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
                          if (approved) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'KINGCLUB 是年轻人的单身交友俱乐部，会员需要遵守会员规则，文明绿色交友，遵守国家相关法律法规，拒绝黄赌毒。',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: KingColors.textSecondary,
                              ),
                            ),
                          ],
                          if (!approved) ...[
                            const SizedBox(height: 16),
                            if (member.registrationStatus == 'pending_review')
                              Theme(
                                data: Theme.of(context).copyWith(
                                  splashFactory: NoSplash.splashFactory,
                                  splashColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                ),
                                child: ExpansionTile(
                                  key: ValueKey(
                                    'review-reason-$expandReviewReason',
                                  ),
                                  initiallyExpanded: expandReviewReason,
                                  backgroundColor: Colors.transparent,
                                  collapsedBackgroundColor: Colors.transparent,
                                  tilePadding: EdgeInsets.zero,
                                  childrenPadding: const EdgeInsets.only(
                                    bottom: 8,
                                  ),
                                  shape: const Border(),
                                  collapsedShape: const Border(),
                                  iconColor: KingColors.brandStrong,
                                  collapsedIconColor: KingColors.brandStrong,
                                  title: const Text(
                                    '为什么需要等待审核？',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: KingColors.brandStrong,
                                    ),
                                  ),
                                  children: const [
                                    Text(
                                      '照片清晰度、拍摄角度或光线可能影响自动评分，因此需要人工进一步确认。您也可以更换清晰、光线均匀的形象照片后重新提交。评分仅供本次申请参考。',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: KingColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
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
                if (!restricted &&
                    member.registrationStatus == 'pending_review')
                  TextButton(
                    onPressed: widget.onImages,
                    child: const Text('更换形象照片'),
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 45),
                  child: FilledButton(
                    onPressed: _loading
                        ? null
                        : approved
                        ? widget.onApproved
                        : _refresh,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(45),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      approved
                          ? '进入 KINGCLUB'
                          : _loading
                          ? '正在刷新'
                          : '刷新状态',
                    ),
                  ),
                ),
                Visibility(
                  visible: !approved,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: TextButton(
                    onPressed: widget.onBack,
                    child: const Text('返回登录页'),
                  ),
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
