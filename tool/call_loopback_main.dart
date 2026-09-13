// Device-only SDK probe. Use --flavor calltest, never preview.
// No account store, HTTP signaling, microphone or camera capture. Host ICE
// connects two native peers in the same app using synthetic channel messages.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/auth/domain/auth_repository.dart';
import 'package:kingclub/src/features/messaging/data/call_media_session.dart';
import 'package:kingclub/src/features/messaging/data/call_repository.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';
import 'package:kingclub/src/features/messaging/data/native_call_media.dart';

const _id = '00000000-0000-4000-8000-000000000001';
final _status = ValueNotifier('Running local WebRTC probe');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: _status,
            builder: (_, text, _) => Text(text, textAlign: TextAlign.center),
          ),
        ),
      ),
    ),
  );
  unawaited(_run());
}

void _require(bool condition, String stage) {
  if (!condition) throw StateError(stage);
}

void _mark(String value) {
  debugPrint('KINGCLUB_RTC_PROBE_$value');
  _status.value = value;
}

Future<void> _run() async {
  final sessions = <CallMediaSession>[];
  final channels = <RTCDataChannel>[];
  final signals = <Map<String, dynamic>>[];
  var generation = 0, captures = 0;
  var stage = 'SETUP';
  var callerConnected = false, calleeConnected = false;
  final received = <String>[];
  RTCDataChannel? callerChannel, calleeChannel;
  try {
    Map<String, dynamic> snapshot(String phase) => {
      'callId': _id,
      'caller': 'probe-a',
      'callee': 'probe-b',
      'mediaKind': 'audio',
      'phase': phase,
      'version': 3,
      'deadlineMs': DateTime.now().millisecondsSinceEpoch + 45000,
    };
    CallRepository repository(String account) => CallRepository(
      MessagingRepository(
        account: account,
        call: (method, params) async {
          if (method == 'K260913000645') return {'call': snapshot('active')};
          if (method == 'K260914000648') {
            final expiry =
                (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 600) * 1000;
            return {
              'expiresAtMs': expiry,
              'iceServers': [
                {
                  // Deliberately nonexistent local relay. Connectivity must use host
                  // candidates; this exercises native configuration, not TURN service.
                  'urls': ['turn:127.0.0.1:9?transport=udp'],
                  'username':
                      '${expiry ~/ 1000}:0123456789abcdef0123456789abcdef',
                  'credential': 'AAAAAAAAAAAAAAAAAAAAAAAAAAA=',
                },
              ],
            };
          }
          if (method == 'K260913000647') {
            final rows = signals
                .where(
                  (row) =>
                      row['sender'] != account &&
                      (row['sequence'] as int) > (params['after'] as int) &&
                      row['signal']['generation'] == generation,
                )
                .toList();
            return {
              'items': rows,
              'generation': generation,
              'hasMore': false,
              'nextSequence': rows.isEmpty
                  ? params['after']
                  : rows.last['sequence'],
            };
          }
          _require(method == 'K260913000646', 'unexpected method');
          final signal = Map<String, dynamic>.from(params['signal'] as Map);
          final old = signals.where(
            (row) =>
                row['signal']['clientSignalId'] == signal['clientSignalId'],
          );
          if (old.isNotEmpty) {
            return {
              'sequence': old.first['sequence'],
              'generation': old.first['signal']['generation'],
              'replay': true,
            };
          }
          if (signal['kind'] == 'offer') {
            generation = signal['generation'] as int;
          }
          if (signal['generation'] != generation) {
            throw const AuthFailure('CHAT_CALL_NEGOTIATION_CONFLICT', 'stale');
          }
          signals.add({
            'sender': account,
            'sequence': signals.length + 1,
            'signal': signal,
          });
          return {
            'sequence': signals.length,
            'generation': generation,
            'replay': false,
          };
        },
      ),
    );
    CallMediaSession create(String account) {
      final session = CallMediaSession(
        repository: repository(account),
        call: CallSnapshot.parse(snapshot('connecting'), account),
        mediaFactory: (onCandidate) => NativeCallMedia(
          video: false,
          iceServers: [],
          onCandidate: onCandidate,
          capture: (_) async {
            captures++;
            return createLocalMediaStream(account); // Empty stream, no devices.
          },
          onConnection: (state) {
            final connected =
                state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
            if (account == 'probe-a') {
              callerConnected = connected;
            } else {
              calleeConnected = connected;
            }
          },
          peerFactory: (config) async {
            final peer = await createPeerConnection(config);
            if (account == 'probe-a') {
              callerChannel = await peer.createDataChannel(
                'local-probe',
                RTCDataChannelInit(),
              );
              channels.add(callerChannel!);
              callerChannel!.onMessage = (message) =>
                  received.add(message.text);
            } else {
              peer.onDataChannel = (channel) {
                calleeChannel = channel;
                channels.add(channel);
                channel.onMessage = (message) => received.add(message.text);
              };
            }
            return peer;
          },
        ),
      );
      sessions.add(session);
      return session;
    }

    final caller = create('probe-a'), callee = create('probe-b');
    Future<void> until(bool Function() ready) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (!ready()) {
        _require(DateTime.now().isBefore(deadline), 'negotiation timeout');
        await caller.sync(renewLease: false);
        await callee.sync(renewLease: false);
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    }

    bool connected() =>
        callerConnected &&
        calleeConnected &&
        caller.canRestart &&
        callerChannel?.state == RTCDataChannelState.RTCDataChannelOpen &&
        calleeChannel?.state == RTCDataChannelState.RTCDataChannelOpen;
    stage = 'INITIAL_NEGOTIATION';
    await until(connected);
    stage = 'INITIAL_MESSAGES';
    await callerChannel!.send(RTCDataChannelMessage('before-a'));
    await calleeChannel!.send(RTCDataChannelMessage('before-b'));
    await until(
      () => received.contains('before-a') && received.contains('before-b'),
    );
    _mark('INITIAL_BIDIRECTIONAL_PASSED');
    final originalCallerChannel = callerChannel,
        originalCalleeChannel = calleeChannel;
    stage = 'RESTART_NEGOTIATION';
    await caller.restart();
    await until(
      () => caller.generation == 1 && callee.generation == 1 && connected(),
    );
    final offers = signals
        .where((row) => row['signal']['kind'] == 'offer')
        .toList();
    final ufrag = RegExp(r'a=ice-ufrag:([^\r\n]+)');
    final before = ufrag
        .firstMatch(offers.first['signal']['sdp'] as String)
        ?.group(1);
    final after = ufrag
        .firstMatch(offers.last['signal']['sdp'] as String)
        ?.group(1);
    _require(
      before != null && after != null && before != after,
      'ICE did not restart',
    );
    stage = 'RESTART_MESSAGES';
    await callerChannel!.send(RTCDataChannelMessage('after-a'));
    await calleeChannel!.send(RTCDataChannelMessage('after-b'));
    await until(
      () => received.contains('after-a') && received.contains('after-b'),
    );
    _require(
      identical(originalCallerChannel, callerChannel) &&
          identical(originalCalleeChannel, calleeChannel) &&
          channels.length == 2 &&
          captures == 2,
      'resources recreated',
    );
    _mark('RESTART_BIDIRECTIONAL_PASSED');
  } catch (error) {
    // Never print SDP, ICE addresses, bearer credentials or arbitrary SDK errors.
    _mark('FAILED_${stage}_${error.runtimeType}');
  } finally {
    for (final channel in channels) {
      await channel.close();
    }
    for (final session in sessions) {
      await session.close();
    }
    _mark('CLEANUP_FINISHED');
  }
}
