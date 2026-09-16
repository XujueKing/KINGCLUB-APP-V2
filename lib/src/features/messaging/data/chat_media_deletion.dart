import 'dart:async';

class ChatMediaDeletion {
  const ChatMediaDeletion(this.account, this.group, this.messageId);
  final String account, messageId;
  final bool group;
  static final _listeners = <FutureOr<void> Function(ChatMediaDeletion)>{};

  static void Function() listen(
    FutureOr<void> Function(ChatMediaDeletion) listener,
  ) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  /// Stop active users before removing their files. Failure keeps history
  /// metadata available so explicit cleanup can be retried.
  Future<void> dispatch() async {
    await Future.wait(
      _listeners.toList().map((listener) async => listener(this)),
    );
  }
}
