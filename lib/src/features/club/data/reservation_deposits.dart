import '../../../core/session/member_qr_memory.dart';
import '../../profile_settings/data/profile_repository.dart';

Future<Map<String, dynamic>> callReservationDeposit(
  Map<String, dynamic> input,
) async {
  final generation = MemberQrMemory.presentationGeneration;
  final result = await ProfileRepository().call('K261008002055', input);
  if (generation != MemberQrMemory.presentationGeneration) {
    throw StateError('会话已变化，请重新打开页面');
  }
  return result;
}

/// Validate a complete original-order projection, never an SDK success signal.
Map<String, dynamic> reservationDepositResult(
  Map<String, dynamic> result,
  String depositRef,
) {
  const statuses = {
    'paying',
    'reserved',
    'arrived',
    'closed',
    'refund_pending',
    'refunded',
  };
  final amount = result['amountCents']?.toString() ?? '';
  final snapshot = result['snapshot'];
  final reservation = result['reservation'];
  final refund = result['refund'];
  if (result['depositRef'] != depositRef ||
      !statuses.contains(result['status']) ||
      !RegExp(r'^[1-9][0-9]{0,8}$').hasMatch(amount) ||
      snapshot is! Map ||
      snapshot['currency'] != 'CNY' ||
      snapshot['storeName'] is! String ||
      snapshot['tableName'] is! String ||
      (reservation != null &&
          (reservation is! Map || reservation['ref'] != depositRef)) ||
      (['reserved', 'arrived'].contains(result['status']) &&
          reservation == null) ||
      (['refund_pending', 'refunded'].contains(result['status']) &&
          (refund is! Map ||
              refund['amountCents']?.toString() != amount ||
              !{
                'prepared',
                'sending',
                'review',
                'refunded',
              }.contains(refund['status']))) ||
      (result['status'] == 'refunded' &&
          (refund is! Map || refund['status'] != 'refunded'))) {
    throw const FormatException('预约定金原单资料不完整，请重新核对');
  }
  return result;
}
