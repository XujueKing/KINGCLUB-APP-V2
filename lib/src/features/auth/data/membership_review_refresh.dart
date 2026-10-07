import '../domain/auth_repository.dart';

/// Realtime events are refresh hints. Only the server response grants entry.
class MembershipReviewRefresh {
  MembershipReviewRefresh({
    required this.readMember,
    required this.readSession,
    required this.refreshMembership,
    required this.onApproved,
  });

  final AuthLoginResult? Function() readMember;
  final Future<Map<String, dynamic>?> Function() readSession;
  final Future<AuthLoginResult> Function() refreshMembership;
  final void Function(String sessionId) onApproved;
  bool _busy = false, _closed = false;
  bool get _pending {
    final member = readMember();
    return member?.isRealSession == true &&
        member?.accountStatus == 'active' &&
        member?.membershipStatus == 'active' &&
        member?.registrationStatus == 'pending_review';
  }

  Future<void> notify() async {
    if (_closed || _busy || !_pending) return;
    _busy = true;
    try {
      final before = await readSession();
      if (_closed || !_pending || before?['sessionId'] is! String) return;
      final approved = await refreshMembership();
      final after = await readSession();
      if (_closed ||
          !approved.canEnterApp ||
          readMember()?.canEnterApp != true ||
          before?['sessionId'] != after?['sessionId'] ||
          (before?['account'] as Map?)?['userAccount'] !=
              (after?['account'] as Map?)?['userAccount']) {
        return;
      }
      onApproved(before!['sessionId'] as String);
    } catch (_) {
      // A temporary outage cannot approve a member or discard the session.
      // A later reconnect/resume or the page's refresh can retry.
    } finally {
      _busy = false;
    }
  }

  void close() => _closed = true;
}
