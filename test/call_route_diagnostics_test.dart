import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:kingclub/src/features/messaging/data/call_route_diagnostics.dart';

void main() {
  StatsReport report(String id, String type, Map<String, dynamic> values) =>
      StatsReport(id, type, 0, values);
  List<StatsReport> fixture(String remoteType) => [
    report('t', 'transport', {'selectedCandidatePairId': 'p'}),
    report('p', 'candidate-pair', {
      'state': 'succeeded',
      'localCandidateId': 'l',
      'remoteCandidateId': 'r',
      'bytesSent': 2048,
      'bytesReceived': 4096,
    }),
    report('l', 'local-candidate', {
      'candidateType': 'srflx',
      'protocol': 'udp',
      'address': 'PRIVATE_ADDRESS',
    }),
    report('r', 'remote-candidate', {'candidateType': remoteType}),
  ];
  test('selected pair reports transport and counters without address', () {
    final result = callRouteDiagnostics(fixture('prflx')).single;
    expect(result, contains('route=direct'));
    expect(result, contains('sent=2048 received=4096'));
    expect(result, isNot(contains('PRIVATE_ADDRESS')));
  });
  test('either relay candidate means relay and unknown stays unknown', () {
    expect(
      callRouteDiagnostics(fixture('relay')).single,
      contains('route=relay'),
    );
    expect(
      callRouteDiagnostics(fixture('unexpected')).single,
      contains('route=unknown'),
    );
  });
  test('successful unselected pairs are not direct connection evidence', () {
    expect(callRouteDiagnostics(fixture('host').skip(1).toList()), isEmpty);
    final rows = fixture('host');
    rows[0] = report('t', 'transport', {'selectedCandidatePairId': 'missing'});
    expect(callRouteDiagnostics(rows), isEmpty);
  });
  test('audio diagnostics separate capture, RTP and missing data without identifiers', () {
    final rows = [
      report('PRIVATE_ID', 'media-source', {
        'kind': 'audio',
        'audioLevel': 0.3,
        'totalAudioEnergy': 2.5,
        'trackIdentifier': 'PRIVATE_TRACK',
      }),
      report('out', 'outbound-rtp', {
        'kind': 'audio',
        'packetsSent': 42,
        'bytesSent': 2000,
      }),
      report('in', 'inbound-rtp', {
        'mediaType': 'audio',
        'packetsReceived': 40,
        'totalAudioEnergy': 0,
        'audioLevel': double.nan,
        'packetsLost': -1,
      }),
      report('video', 'outbound-rtp', {'kind': 'video', 'packetsSent': 999}),
    ];
    final result = callAudioDiagnostics(rows);
    expect(result, hasLength(3));
    expect(result[0], contains('totalAudioEnergy=2.5'));
    expect(result[0], contains('totalSamplesDuration=unavailable'));
    expect(result[1], contains('packetsSent=42 bytesSent=2000'));
    expect(
      result[2],
      contains('packetsLost=-1 audioLevel=unavailable totalAudioEnergy=0'),
    );
    expect(result.join(), isNot(contains('PRIVATE')));
    expect(result.join(), isNot(contains('999')));
  });
}
