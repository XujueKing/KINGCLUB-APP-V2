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
}
