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
