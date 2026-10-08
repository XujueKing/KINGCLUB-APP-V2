import '../../../core/session/member_qr_memory.dart';
import '../../profile_settings/data/profile_repository.dart';

typedef ReservationCall = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> input,
);

Future<Map<String, dynamic>> callReservationProducts(
  Map<String, dynamic> input,
) async {
  final generation = MemberQrMemory.presentationGeneration;
  final result = await ProfileRepository().call('K261008002050', input);
  if (generation != MemberQrMemory.presentationGeneration) {
    throw StateError('会话已变化，请重新打开页面');
  }
  return result;
}

List<Map<String, dynamic>> reservationRows(Object? value) =>
    (value as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
bool reservationFlag(Object? value) => value == true || value == 1;
int reservationCents(Object? value) => int.parse(value.toString());

/// Only input validation. Final amounts and availability come from the procedure.
int? reservationAmountInput(String text) {
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text.trim())) return null;
  final parts = text.trim().split('.');
  final cents =
      int.parse(parts[0]) * 100 +
      int.parse(parts.length == 1 ? '00' : parts[1].padRight(2, '0'));
  return cents <= 999999999 ? cents : null;
}
