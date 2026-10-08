import '../../../core/session/member_qr_memory.dart';
import '../../profile_settings/data/profile_repository.dart';

Future<Map<String, dynamic>> callMonthlyContracts(
  Map<String, dynamic> input,
) async {
  final generation = MemberQrMemory.presentationGeneration;
  final result = await ProfileRepository().call('K261008002051', input);
  if (generation != MemberQrMemory.presentationGeneration) {
    throw StateError('会话已变化，请重新打开页面');
  }
  return result;
}

Future<Map<String, dynamic>> callContractFunds(
  Map<String, dynamic> input,
) async {
  final generation = MemberQrMemory.presentationGeneration;
  final result = await ProfileRepository().call('K261008002053', input);
  if (generation != MemberQrMemory.presentationGeneration) {
    throw StateError('会话已变化，请重新打开页面');
  }
  return result;
}
