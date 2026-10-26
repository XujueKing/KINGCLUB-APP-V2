import 'together_play.dart';

import 'dart:typed_data';

enum TogetherFeedView { recommendations, tickets, history, purchases }

class TogetherFeedPage {
  const TogetherFeedPage(this.items, this.next, {this.avatarBytes});
  final List<TogetherParty> items;
  final String? next;
  final Uint8List? avatarBytes;
}

abstract interface class TogetherFeedRepository {
  Future<TogetherFeedPage> feed({
    required TogetherFeedView view,
    String? cityCode,
    String? storeRef,
    DateTime? date,
    String? after,
  });
}
