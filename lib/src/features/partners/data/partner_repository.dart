import '../../profile_settings/data/profile_repository.dart';

typedef PartnerCall = Future<Map<String, dynamic>> Function(
  Map<String, dynamic>,
);

class PartnerRepository {
  final _profile = ProfileRepository();
  Future<Map<String, dynamic>> call(Map<String, dynamic> params) =>
      _profile.call('K261007002030', params);
}

class PartnerContext {
  PartnerContext(Map<String, dynamic> value)
    : partner = value['partner'] == null
          ? null
          : Map<String, dynamic>.from(value['partner'] as Map),
      application = value['application'] == null
          ? null
          : Map<String, dynamic>.from(value['application'] as Map),
      stores = (value['stores'] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList(),
      admin = value['isAdmin'] == true || value['isAdmin'] == 1,
      teamCount = value['teamCount'] as int,
      customerCount = value['customerCount'] as int {
    if (partner != null &&
        (!['active', 'suspended'].contains(partner!['status']) ||
            partner!['level'] is! int ||
            (partner!['level'] as int) < 1 ||
            (partner!['level'] as int) > 15 ||
            partner!['organizerBps'] !=
                ((partner!['level'] as int) + 5) * 100)) {
      throw const FormatException('Invalid partner status');
    }
    if (application != null &&
        !['pending', 'approved', 'rejected'].contains(application!['status'])) {
      throw const FormatException('Invalid application status');
    }
  }
  final Map<String, dynamic>? partner, application;
  final List<Map<String, dynamic>> stores;
  final bool admin;
  final int teamCount, customerCount;
}
