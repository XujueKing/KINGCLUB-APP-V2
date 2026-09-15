import 'dart:async';

import 'group_call_controller.dart';
import 'group_call_media_repository.dart';
import 'group_call_repository.dart';
import 'native_group_call_media.dart';

/// Owns one explicitly opened call. Merely showing an invitation never captures.
class GroupCallSession {
  GroupCallSession({
    required this.controller,
    NativeGroupCallMedia Function(
      GroupCallMediaRepository repository,
      void Function(String, String) connection,
      void Function(Object) error,
    )?
    createMedia,
    this.onError,
    this.heartbeatInterval = const Duration(seconds: 10),
  }) : _createMedia =
           createMedia ??
           ((repository, connection, error) => NativeGroupCallMedia(
             repository: repository,
             onConnection: connection,
             onError: error,
           )) {
    if (heartbeatInterval <= Duration.zero) {
      throw ArgumentError('Invalid heartbeat');
    }
    controller.addListener(_stateChanged);
  }

  final GroupCallController controller;
  final NativeGroupCallMedia Function(
    GroupCallMediaRepository,
    void Function(String, String),
    void Function(Object),
  )
  _createMedia;
  final void Function(Object)? onError;
  final Duration heartbeatInterval;
  NativeGroupCallMedia? _media;
  NativeGroupCallMedia? get media => _media;
  bool _closed = false, _sendConnected = false, _renewing = false;
  bool _receiveConnected = false, _everConnected = false;
  final _duration = Stopwatch();
  bool get isConnected => !_closed && _sendConnected && _receiveConnected;
  Duration? get connectedDuration => _everConnected ? _duration.elapsed : null;
  Future<void>? _opening, _closing;
  Timer? _heartbeat;
  bool get isClosed => _closed;

  void _check() {
    if (_closed || controller.isClosed) throw StateError('Group call closed');
  }

  /// Call only from an explicit start/accept action, including an outgoing call.
  Future<void> enter() {
    _check();
    return _opening ??= _enter().whenComplete(() => _opening = null);
  }

  Future<void> _enter() async {
    try {
      final self = controller.call.participants.singleWhere(
        (p) => p.account == controller.repository.messaging.account,
      );
      if (self.phase == GroupCallPhase.invited) {
        await controller.act(GroupCallAction.join);
      }
      _check();
      if (controller.call.participants
              .singleWhere(
                (p) => p.account == controller.repository.messaging.account,
              )
              .phase !=
          GroupCallPhase.joined) {
        throw StateError('Group call not joined');
      }
      _media ??= _createMedia(
        GroupCallMediaRepository(
          controller.repository.messaging,
          controller.call,
        ),
        _connection,
        _failed,
      );
      await _media!.open();
      _check();
      controller.watch();
      _heartbeat ??= Timer.periodic(
        heartbeatInterval,
        (_) => unawaited(_renew()),
      );
    } catch (error) {
      // A failed join can be retried with the controller's retained request ID.
      // Once capture has started, failure terminates its owner instead.
      if (_media != null) await close();
      rethrow;
    }
  }

  void _connection(String direction, String state) {
    if (_closed) return;
    if (direction == 'send') _sendConnected = state == 'connected';
    if (direction == 'receive') _receiveConnected = state == 'connected';
    if (isConnected && !_everConnected) {
      _everConnected = true;
      _duration.start();
    }
  }

  Future<void> _renew() async {
    if (_closed || !_sendConnected || _renewing || _media?.isClosed != false) {
      return;
    }
    _renewing = true;
    try {
      await controller.act(
        GroupCallAction.heartbeat,
        canSend: () => !_closed && _sendConnected && _media?.isClosed == false,
      );
    } catch (error) {
      if (!_closed) onError?.call(error);
    } finally {
      _renewing = false;
    }
  }

  void _stateChanged() {
    if (controller.isClosed) unawaited(close());
  }

  void _failed(Object error) {
    if (_closed) return;
    unawaited(close());
    onError?.call(error);
  }

  Future<void> hangUp() async {
    // Stop capture immediately, before waiting for any network acknowledgement.
    _closed = true;
    _duration.stop();
    _heartbeat?.cancel();
    _sendConnected = false;
    await _media?.close();
    try {
      try {
        await _opening;
      } catch (_) {
        // A canceled enter may already have joined on the server. Use the
        // reconciled phase below to leave instead of declining a joined seat.
      }
      if (!controller.isClosed) {
        final self = controller.call.participants.singleWhere(
          (p) => p.account == controller.repository.messaging.account,
        );
        await controller.act(
          self.phase == GroupCallPhase.invited
              ? GroupCallAction.decline
              : GroupCallAction.leave,
        );
      }
    } finally {
      await close();
    }
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    _closed = true;
    _duration.stop();
    _heartbeat?.cancel();
    controller.removeListener(_stateChanged);
    controller.close();
    return _closing = _media?.close() ?? Future.value();
  }
}
