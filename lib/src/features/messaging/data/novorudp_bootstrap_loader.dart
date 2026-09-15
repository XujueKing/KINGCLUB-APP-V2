import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../core/session/member_qr_memory.dart';
import '../../../core/session/secure_session_store.dart';
import 'novorudp_relay_directory.dart';
import 'novorudp_secure_session.dart';

/// Fetches candidates, never member permissions or a new trust root.
class NovoRudpBootstrapLoader {
  final int _generation = MemberQrMemory.generation;
  HttpClient? _client;
  bool _closed = false, _loading = false;

  void _check() {
    if (_closed || _generation != MemberQrMemory.generation) {
      close();
      throw StateError('Bootstrap loader closed');
    }
  }

  Future<NovoRudpRelayDirectory> load({
    required NovoRudpSecureSession identity,
    required List<Uri> sources,
    required Set<String> trustedSignerPeerIds,
    required int minimumSignatures,
    Duration sourceTimeout = const Duration(seconds: 3),
  }) async {
    _check();
    if (_loading) throw StateError('Bootstrap load already pending');
    final endpoints = List<Uri>.of(sources);
    final trusted = Set<String>.of(trustedSignerPeerIds);
    if (endpoints.isEmpty ||
        endpoints.length > 8 ||
        trusted.isEmpty ||
        trusted.length > 16 ||
        trusted.any(
          (key) => !RegExp(r'^novovm-ed25519:[0-9a-f]{64}$').hasMatch(key),
        ) ||
        minimumSignatures < 1 ||
        minimumSignatures > trusted.length ||
        sourceTimeout <= Duration.zero ||
        sourceTimeout > const Duration(seconds: 10)) {
      throw ArgumentError('Invalid bootstrap configuration');
    }
    for (final uri in endpoints) {
      final local = InternetAddress.tryParse(uri.host)?.isLoopback ?? false;
      if (!uri.hasAuthority ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment ||
          uri.hasQuery ||
          uri.port < 1 ||
          uri.port > 65535 ||
          (uri.scheme != 'https' && !(uri.scheme == 'http' && local))) {
        throw ArgumentError(
          'Bootstrap requires HTTPS or literal loopback HTTP',
        );
      }
    }
    _loading = true;
    final changes = SecureSessionStore.changes.stream.listen((_) => close());
    try {
      for (final uri in endpoints) {
        _check();
        final client = _client = HttpClient()
          ..connectionTimeout = sourceTimeout;
        try {
          final manifest = await _fetch(client, uri).timeout(sourceTimeout);
          _check();
          final directory = NovoRudpRelayDirectory.fromManifest(
            identity: identity,
            manifest: manifest,
            trustedSignerPeerIds: trusted,
            minimumSignatures: minimumSignatures,
          );
          if (directory.candidates.isNotEmpty) return directory;
          directory.close();
        } on IOException {
          // Try the next independent, configured source.
        } on TimeoutException {
          // The finally block closes even a connection that completes late.
        } on FormatException {
          // Malformed JSON is never a usable directory.
        } on StateError {
          // Includes native signature/expiry rejection. Lifecycle checked below.
        } finally {
          client.close(force: true);
          if (identical(_client, client)) _client = null;
        }
        _check();
      }
      throw StateError('No verified bootstrap candidates available');
    } finally {
      _loading = false;
      await changes.cancel();
    }
  }

  Future<Map<String, dynamic>> _fetch(HttpClient client, Uri uri) async {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw const HttpException('Bootstrap source unavailable');
    }
    // Leave space for trusted keys and FFI envelope in the 16 KiB native request.
    const limit = 12 * 1024;
    if (response.contentLength > limit) {
      throw const FormatException('Bootstrap too large');
    }
    final bytes = <int>[];
    await for (final chunk in response) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('Bootstrap too large');
      }
      bytes.addAll(chunk);
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid bootstrap object');
    }
    return value;
  }

  void close() {
    _closed = true;
    _client?.close(force: true);
    _client = null;
  }
}
