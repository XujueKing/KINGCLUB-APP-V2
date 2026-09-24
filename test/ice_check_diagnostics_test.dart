import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/messaging/data/ice_check_diagnostics.dart';

void main() {
  StatsReport row(String id, String type, Map<String, dynamic> values) =>
      StatsReport(id, type, 0, values);

  test(
    'failed checks aggregate counts without exposing network identifiers',
    () {
      final rows = [
        row('local-secret', 'local-candidate', {
          'candidateType': 'srflx',
          'protocol': 'udp',
          'address': '192.0.2.123',
          'url': 'stun:private.example',
        }),
        row('remote-secret', 'remote-candidate', {
          'candidateType': 'host',
          'address': '2001:db8::123',
        }),
        for (var i = 0; i < 2; i++)
          row('pair-secret-$i', 'candidate-pair', {
            'localCandidateId': 'local-secret',
            'remoteCandidateId': 'remote-secret',
            'state': 'failed',
            'requestsSent': 4,
            'responsesReceived': 0,
          }),
      ];
      final output = iceCheckDiagnostics(rows).join('\n');
      expect(output, contains('local=srflx/v4 remote=host/v6'));
      expect(output, contains('state=failed count=2 requestsSent=8(2/2)'));
      expect(output, contains('responsesReceived=0(2/2)'));
      expect(output, contains('requestsReceived=0(0/2)'));
      for (final secret in [
        'secret',
        '192.0.2.123',
        '2001:db8',
        'private.example',
      ]) {
        expect(output, isNot(contains(secret)));
      }
      expect(output, isNot(contains('route=direct')));
    },
  );

  test('missing, invalid counters and candidate labels stay unknown', () {
    final output = iceCheckDiagnostics([
      row('l', 'local-candidate', {
        'candidateType': 'PRIVATE',
        'protocol': 'PRIVATE',
        'address': 'private.local',
      }),
      row('p', 'candidate-pair', {
        'localCandidateId': 'l',
        'state': 'PRIVATE',
        'requestsSent': double.nan,
        'responsesReceived': -1,
        'requestsReceived': double.infinity,
        'responsesSent': 'PRIVATE',
      }),
    ]).join('\n');
    expect(output, contains('local=unknown/unknown remote=unknown/unknown'));
    expect(output, contains('protocol=unknown state=unknown'));
    expect(output, contains('requestsSent=0(0/1)'));
    expect(output, isNot(contains('PRIVATE')));
    expect(output, isNot(contains('private.local')));
    expect(iceCheckDiagnostics([]).single, contains('pairs=0'));
  });
}
