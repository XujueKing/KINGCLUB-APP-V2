import 'dart:convert';
import 'dart:io';

/// Optional build-time public CA for a private test relay. Never disables TLS
/// hostname/expiry validation and does not replace the relay's Ed25519 pin.
SecurityContext? relaySecurityContext(String encodedCertificate) {
  if (encodedCertificate.isEmpty) return null;
  if (encodedCertificate.length > 65536) {
    throw const FormatException('Relay certificate too large');
  }
  final bytes = base64Decode(encodedCertificate);
  final pem = utf8.decode(bytes).trim();
  if (!pem.startsWith('-----BEGIN CERTIFICATE-----') ||
      !pem.endsWith('-----END CERTIFICATE-----') ||
      pem.contains('PRIVATE KEY')) {
    throw const FormatException('Relay requires a public PEM certificate');
  }
  return SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(bytes);
}
