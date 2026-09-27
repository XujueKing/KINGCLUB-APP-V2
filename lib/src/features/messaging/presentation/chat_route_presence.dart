import 'package:flutter/widgets.dart';

typedef ChatRouteIdentity = ({String account, String target, bool group});

/// Tracks live routes only. Reading identity lazily preserves account isolation
/// while a conversation restores its repository after a session change.
class ChatRoutePresence {
  static final instance = ChatRoutePresence();
  final _entries = <Object, (Route<dynamic>, ChatRouteIdentity? Function())>{};

  VoidCallback register(
    Route<dynamic> route,
    ChatRouteIdentity? Function() identity,
  ) {
    final owner = Object();
    _entries[owner] = (route, identity);
    return () => _entries.remove(owner);
  }

  bool isCurrent(NavigatorState navigator, ChatRouteIdentity identity) =>
      _entries.values.any(
        (entry) =>
            identical(entry.$1.navigator, navigator) &&
            entry.$1.isCurrent &&
            entry.$2() == identity,
      );
}
