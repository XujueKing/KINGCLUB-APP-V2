/// One foreground call flow across direct/group, incoming/outgoing routes.
/// Acquire before asynchronous dial setup and release only when that flow ends.
class CallPresentationLease {
  CallPresentationLease._();
  static CallPresentationLease? _owner;

  static CallPresentationLease? acquire() {
    if (_owner != null) return null;
    return _owner = CallPresentationLease._();
  }

  void release() {
    if (identical(_owner, this)) _owner = null;
  }
}

/// Tracks one presenter's ownership across account and navigator lifetimes.
class CallPresentationOwner {
  CallPresentationLease? _lease;
  CallPresentationLease? acquire() {
    if (_lease != null) return null;
    return _lease = CallPresentationLease.acquire();
  }

  void release(CallPresentationLease lease) {
    lease.release();
    if (identical(_lease, lease)) _lease = null;
  }

  void reset() {
    _lease?.release();
    _lease = null;
  }
}
