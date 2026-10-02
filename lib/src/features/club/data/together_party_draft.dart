import 'together_play.dart';
import 'together_store.dart';

enum TogetherArtworkStatus { approved, pending, rejected }

class TogetherArtwork {
  const TogetherArtwork({
    required this.ref,
    required this.name,
    required this.url,
    required this.status,
    this.rejectionReason,
  });
  final String ref, name, url;
  final TogetherArtworkStatus status;
  final String? rejectionReason;
}

/// Creation input only. The server must recheck table capacity, asset approval,
/// authenticated host rights and quote the wallet hold before publication.
class TogetherPartyDraft {
  const TogetherPartyDraft({
    required this.theme,
    required this.cityCode,
    required this.store,
    required this.place,
    required this.startsAt,
    required this.endsAt,
    required this.capacity,
    required this.feeMode,
    required this.priceMinor,
    required this.totalCostMinor,
    required this.description,
    required this.background,
    required this.poster,
    this.table,
  });
  final String theme, cityCode, place, description;
  final TogetherStore store;
  final TogetherTable? table;
  String get storeRef => store.ref;
  String? get tableRef => table?.ref;
  final DateTime startsAt, endsAt;
  final int capacity, priceMinor, totalCostMinor;
  final TogetherFeeMode feeMode;
  final TogetherArtwork background, poster;

  String? validate({required DateTime now}) {
    if (theme.trim().isEmpty || theme.trim().length > 30) {
      return '请填写30字以内的派对主题';
    }
    if (cityCode.isEmpty || place.trim().isEmpty) return '请选择城市并填写活动地点';
    if (store.ref.isEmpty || store.cityCode != cityCode) return '请选择当前城市的门店';
    if (table != null && (table!.ref.isEmpty || table!.storeRef != store.ref)) {
      return '请重新选择该门店的桌台';
    }
    if (!startsAt.isAfter(now) || !endsAt.isAfter(startsAt)) {
      return '请检查活动开始和结束时间';
    }
    if (capacity < 2) return '总人数至少为2人';
    if (table != null && table!.maximumSeats < 2) return '该桌台暂不可用于组局';
    if (table != null && capacity > table!.maximumSeats) {
      return '总人数不能超过桌台容量';
    }
    if (priceMinor < 0 || totalCostMinor < 0) return '费用不能为负数';
    if (feeMode == TogetherFeeMode.hostTreat && priceMinor != 0) {
      return '请客局参加者费用应为零';
    }
    if (background.status != TogetherArtworkStatus.approved ||
        poster.status != TogetherArtworkStatus.approved) {
      return '背景和海报审核通过后才能发布';
    }
    return null;
  }

  static int? parseMoney(String value) {
    final text = value.trim();
    if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(text)) return null;
    final parts = text.split('.');
    return int.parse(parts.first) * 100 +
        (parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0')));
  }
}
