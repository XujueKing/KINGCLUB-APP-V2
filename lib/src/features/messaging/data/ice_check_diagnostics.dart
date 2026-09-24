import 'dart:io';

import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Aggregate connectivity checks, including failed/unselected pairs.
/// Never emits candidate IDs, addresses, ports, URLs, SDP or certificates.
/// These rows describe attempts, not an established direct route.
List<String> iceCheckDiagnostics(List<StatsReport> reports) {
  final byId = {for (final report in reports) report.id: report};
  String allowed(Object? value, Set<String> values) =>
      values.contains(value) ? value as String : 'unknown';
  String candidate(StatsReport? value) {
    final kind = allowed(value?.values['candidateType'], {
      'host',
      'srflx',
      'prflx',
      'relay',
    });
    final address = value?.values['address'] ?? value?.values['ip'];
    final parsed = address is String ? InternetAddress.tryParse(address) : null;
    final family = parsed == null
        ? 'unknown'
        : parsed.type == InternetAddressType.IPv4
        ? 'v4'
        : 'v6';
    return '$kind/$family';
  }

  final inventory = <String, int>{};
  final groups = <String, List<StatsReport>>{};
  for (final report in reports) {
    if (report.type == 'local-candidate' || report.type == 'remote-candidate') {
      final side = report.type == 'local-candidate' ? 'local' : 'remote';
      final key = '$side=${candidate(report)}';
      inventory.update(key, (n) => n + 1, ifAbsent: () => 1);
    } else if (report.type == 'candidate-pair') {
      final local = byId[report.values['localCandidateId']];
      final remote = byId[report.values['remoteCandidateId']];
      final protocol = allowed(local?.values['protocol'], {'udp', 'tcp'});
      final state = allowed(report.values['state'], {
        'frozen',
        'waiting',
        'in-progress',
        'failed',
        'succeeded',
      });
      final key =
          'local=${candidate(local)} remote=${candidate(remote)} '
          'protocol=$protocol state=$state';
      (groups[key] ??= []).add(report);
    }
  }
  String counter(List<StatsReport> pairs, String field) {
    var total = 0, reported = 0;
    for (final pair in pairs) {
      final value = pair.values[field];
      if (value is num && value.isFinite && value >= 0) {
        total += value.toInt();
        reported++;
      }
    }
    // Missing fields are not proof of zero requests or responses.
    return '$field=$total($reported/${pairs.length})';
  }

  final inventoryKeys = inventory.keys.toList()..sort();
  final groupKeys = groups.keys.toList()..sort();
  return [
    'inventory ${[for (final k in inventoryKeys) '$k:${inventory[k]}'].join(' ')} '
        'pairs=${groups.values.fold<int>(0, (n, v) => n + v.length)}',
    for (final key in groupKeys.take(32))
      'checks $key count=${groups[key]!.length} '
          '${counter(groups[key]!, 'requestsSent')} '
          '${counter(groups[key]!, 'responsesReceived')} '
          '${counter(groups[key]!, 'requestsReceived')} '
          '${counter(groups[key]!, 'responsesSent')}',
    if (groupKeys.length > 32) 'omitted_groups=${groupKeys.length - 32}',
  ];
}
