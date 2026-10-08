import '../../../core/session/member_qr_memory.dart';
import '../../profile_settings/data/profile_repository.dart';

typedef PartyAllocationCall = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> input,
);

Future<Map<String, dynamic>> callPartyAllocation(
  Map<String, dynamic> input,
) async {
  final generation = MemberQrMemory.presentationGeneration;
  final result = await ProfileRepository().call('K261008002054', input);
  if (generation != MemberQrMemory.presentationGeneration) {
    throw StateError('会话已变化，请重新打开页面');
  }
  if (result['storeRef'] != input['storeRef']) throw StateError('门店资料不一致');
  return result;
}
