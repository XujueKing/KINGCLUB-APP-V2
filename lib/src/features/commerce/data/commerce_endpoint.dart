import '../../auth/data/auth_repository_provider.dart';

/// Shares existing login credentials, but targets the worker-free commerce HTTP service.
String commerceEndpoint(String apiBase, {String override = ''}) =>
    override.isNotEmpty
    ? override.replaceFirst(RegExp(r'/+$'), '')
    : apiBase.isEmpty
    ? ''
    : '${apiBase.replaceFirst(RegExp(r'/+$'), '')}/commerce';

String get kingclubCommerceApiBaseUrl => commerceEndpoint(
  kingclubApiBaseUrl,
  override: const String.fromEnvironment('KINGCLUB_COMMERCE_API_BASE_URL'),
);
