import 'package:flutter/services.dart';

enum SystemCallEventKind { incoming, answer, end, ended }

/// IDs only. The caller and media permissions must come from authenticated reads.
class SystemCallEvent {
  SystemCallEvent._(
    this.id,
    this.callId,
    this.account,
    this.group,
    this.kind,
    this.actionId,
  );
  final String id, callId, account;
  final String? actionId;
  final bool group;
  final SystemCallEventKind kind;

  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  factory SystemCallEvent.parse(Object? raw) {
    if (raw is! Map) throw const FormatException('Invalid system call event');
    final id = raw['eventId'], callId = raw['callId'], account = raw['account'];
    final scope = raw['scope'], action = raw['actionId'];
    final kinds = SystemCallEventKind.values.where(
      (v) => v.name == raw['kind'],
    );
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        callId is! String ||
        !_uuid.hasMatch(callId) ||
        account is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(account) ||
        !{'direct', 'group'}.contains(scope) ||
        kinds.length != 1) {
      throw const FormatException('Invalid system call event');
    }
    final kind = kinds.single;
    final actionable =
        kind == SystemCallEventKind.answer || kind == SystemCallEventKind.end;
    if (actionable
        ? (action is! String || !_uuid.hasMatch(action))
        : action != null) {
      throw const FormatException('Invalid system call action');
    }
    return SystemCallEvent._(
      id,
      callId.toLowerCase(),
      account,
      scope == 'group',
      kind,
      action as String?,
    );
  }
}

/// Not registered by app.dart until the authenticated call runtime is connected.
/// Acknowledging receipt never fulfills a system answer action.
class NativeSystemCalls {
  NativeSystemCalls({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('kingclub/system-calls');
  final MethodChannel _channel;

  Future<void> bind(String account) async {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(account)) {
      throw ArgumentError('Invalid system call account');
    }
    await _channel.invokeMethod<void>('bind', {'account': account});
  }

  Future<void> unbind() => _channel.invokeMethod<void>('unbind');
  Future<String?> token() => _channel.invokeMethod<String>('token');
  Future<List<SystemCallEvent>> pending() async {
    final events = await _channel.invokeListMethod<Object?>('pending') ?? [];
    return events.map(SystemCallEvent.parse).toList(growable: false);
  }

  Future<bool> acknowledge(SystemCallEvent event) async =>
      await _channel.invokeMethod<bool>('ack', {'eventId': event.id}) ?? false;
  Future<bool> completeAction(
    SystemCallEvent event, {
    required bool success,
  }) async {
    if (event.actionId == null) throw StateError('Event has no system action');
    return await _channel.invokeMethod<bool>('completeAction', {
          'actionId': event.actionId,
          'success': success,
        }) ??
        false;
  }

  Future<void> end(String callId, {bool failed = false}) =>
      _channel.invokeMethod<void>('end', {'callId': callId, 'failed': failed});

  void listen({
    required Future<void> Function() changed,
    required Future<void> Function(bool) audio,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'changed':
          await changed();
        case 'audioActivated':
          await audio(true);
        case 'audioDeactivated':
          await audio(false);
        default:
          throw MissingPluginException();
      }
    });
  }

  void detach() => _channel.setMethodCallHandler(null);
}
