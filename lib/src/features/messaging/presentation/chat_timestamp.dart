/// Show the first valid timestamp, day boundaries and gaps of five minutes.
/// Wire dates are converted to the phone's local timezone before formatting.
String? chatTimestampLabel(String? date, String? previous, {DateTime? now}) {
  final current = DateTime.tryParse(date ?? '')?.toLocal();
  if (current == null) return null;
  final before = DateTime.tryParse(previous ?? '')?.toLocal();
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  if (before != null &&
      sameDay(current, before) &&
      current.difference(before).abs() < const Duration(minutes: 5)) {
    return null;
  }
  final today = (now ?? DateTime.now()).toLocal();
  final time =
      '${current.hour.toString().padLeft(2, '0')}:'
      '${current.minute.toString().padLeft(2, '0')}';
  if (sameDay(current, today)) return '今天 $time';
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (sameDay(current, yesterday)) return '昨天 $time';
  final year = current.year == today.year ? '' : '${current.year}年';
  return '$year${current.month}月${current.day}日 $time';
}
