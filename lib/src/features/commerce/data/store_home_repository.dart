import '../../../core/session/member_qr_memory.dart';
import '../../profile_settings/data/profile_repository.dart';

typedef StoreHomeCall = Future<Map<String, dynamic>> Function(
  String id,
  Map<String, dynamic> input,
);

/// Every page is supplied by one aggregate procedure. No per-card requests.
class StoreHomeRepository {
  StoreHomeRepository({StoreHomeCall? call})
    : _call = call ?? ProfileRepository().call;
  final StoreHomeCall _call;

  Future<Map<String, dynamic>> _read(
    String id,
    Map<String, dynamic> input,
  ) async {
    final generation = MemberQrMemory.presentationGeneration;
    final result = await _call(id, input);
    if (generation != MemberQrMemory.presentationGeneration) {
      throw StateError('登录状态已变化，请重新打开店铺');
    }
    if (result['store'] is! Map ||
        (result['store'] as Map)['ref'] != input['storeRef']) {
      throw const FormatException('店铺信息暂不可用');
    }
    return result;
  }

  Future<Map<String, dynamic>> home(
    String ref, {
    String section = 'featured',
    int page = 0,
  }) => _read('K261028002080', {
    'storeRef': ref,
    'section': section,
    'page': page,
  });

  Future<Map<String, dynamic>> voucher(String storeRef, String offerRef) async {
    final result = await _read('K261028002081', {
      'storeRef': storeRef,
      'offerRef': offerRef,
    });
    if (result['voucher'] is! Map ||
        (result['voucher'] as Map)['ref'] != offerRef) {
      throw const FormatException('团购券信息暂不可用');
    }
    return result;
  }

  Future<bool> favourite(String storeRef, bool follow) async {
    final generation = MemberQrMemory.presentationGeneration;
    final result = await _call('K261005000810', {
      'storeRef': storeRef,
      'action': follow ? 'follow' : 'unfollow',
    });
    if (generation != MemberQrMemory.presentationGeneration) {
      throw StateError('登录状态已变化');
    }
    return (result['stores'] as List).any(
      (s) => s is Map && s['storeRef'] == storeRef,
    );
  }
}
