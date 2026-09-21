import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Only selected transports are evidence. Never log SDP, addresses or IDs.
List<String> callRouteDiagnostics(List<StatsReport> reports) {
  final byId = {for (final report in reports) report.id: report};
  final results = <String>[];
  for (final transport in reports.where((r) => r.type == 'transport')) {
    final pair = byId[transport.values['selectedCandidatePairId']];
    if (pair == null || pair.type != 'candidate-pair') continue;
    final local = byId[pair.values['localCandidateId']];
    final remote = byId[pair.values['remoteCandidateId']];
    String kind(StatsReport? candidate) {
      final value = candidate?.values['candidateType'];
      return const {'host', 'srflx', 'prflx', 'relay'}.contains(value)
          ? value as String
          : 'unknown';
    }

    final localKind = kind(local), remoteKind = kind(remote);
    final route = localKind == 'relay' || remoteKind == 'relay'
        ? 'relay'
        : localKind == 'unknown' || remoteKind == 'unknown'
        ? 'unknown'
        : 'direct';
    final protocol = local?.values['protocol'];
    final safeProtocol = const {'udp', 'tcp'}.contains(protocol)
        ? protocol
        : 'unknown';
    int count(String name) {
      final value = pair.values[name];
      return value is num && value.isFinite && value >= 0 ? value.toInt() : 0;
    }

    results.add(
      'route=$route local=$localKind remote=$remoteKind protocol=$safeProtocol '
      'succeeded=${pair.values['state'] == 'succeeded'} '
      'sent=${count('bytesSent')} received=${count('bytesReceived')}',
    );
  }
  return results;
}
