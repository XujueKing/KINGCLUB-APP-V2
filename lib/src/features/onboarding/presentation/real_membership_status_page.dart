import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';

class RealMembershipStatusPage extends ConsumerStatefulWidget {
  const RealMembershipStatusPage({
    super.key,
    required this.onApproved,
    required this.onIdentity,
    required this.onBack,
  });
  final VoidCallback onApproved;
  final VoidCallback onIdentity;
  final VoidCallback onBack;
  @override
  ConsumerState<RealMembershipStatusPage> createState() =>
      _RealMembershipStatusPageState();
}

class _RealMembershipStatusPageState
    extends ConsumerState<RealMembershipStatusPage> {
  bool _loading = false;
  String? _error;

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
    final member = ref.watch(authenticatedMemberProvider);
    final restricted =
        member == null ||
        member.accountStatus != 'active' ||
        member.membershipStatus != 'active';
    final message = restricted
        ? '会员状态暂不可用，请重新登录或联系客服'
        : switch (member.registrationStatus) {
            'pending_review' => '入会资格审核中，请耐心等待',
            'photos_required' => '请完成会员形象照片提交',
            'changes_required' => '会员资料需要补充，请按审核要求重新提交',
            'rejected' => '暂未通过入会审核，请联系客服',
            'approved' => '注册已通过，请刷新进入首页',
            _ => '暂时无法确认注册进度，请刷新重试',
          };
    return Scaffold(
      appBar: AppBar(
        title: const Text('会员注册状态'),
        leading: BackButton(onPressed: widget.onBack),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 48),
                const SizedBox(height: 24),
                Text(message, textAlign: TextAlign.center),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _refresh,
                  child: Text(_loading ? '正在刷新' : '刷新状态'),
                ),
                TextButton(onPressed: widget.onBack, child: const Text('返回登录')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
