/// Compact timestamp for the right edge of a conversation list row.
String conversationTimestampLabel(String? date, {DateTime? now}) {
  final current = DateTime.tryParse(date ?? '')?.toLocal();
  if (current == null) return '';
  final today = (now ?? DateTime.now()).toLocal();
  final age = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(current.year, current.month, current.day)).inDays;
  if (age == 0) {
    return '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}';
  }
  if (age == 1) return '昨天';
  if (age >= 2 && age < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return weekdays[current.weekday - 1];
  }
  final year = current.year == today.year ? '' : '${current.year}/';
  return '$year${current.month}/${current.day}';
}

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
  if (sameDay(current, today)) return time;
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  if (sameDay(current, yesterday)) return '昨天 $time';
  // Calendar dates avoid daylight-saving days being 23 or 25 hours long.
  final age = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(current.year, current.month, current.day)).inDays;
  if (age >= 2 && age < 7) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${weekdays[current.weekday - 1]} $time';
  }
  final year = current.year == today.year ? '' : '${current.year}年';
  return '$year${current.month}月${current.day}日 $time';
}
