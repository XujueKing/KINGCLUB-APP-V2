import 'dart:convert';

import 'chat_location.dart';
import 'chat_text_draft_store.dart';

class ChatLocationDraft {
  ChatLocationDraft(this.id, this.location);
  final String id;
  final ChatLocation location;
}

class ChatLocationDraftStore {
  ChatLocationDraftStore(this.store);
  final ChatTextDraftStore store;
  static Future<ChatLocationDraftStore> open(
    String account,
    String target,
  ) async => ChatLocationDraftStore(
    await ChatTextDraftStore.open(account, 'location:$target'),
  );

  Future<ChatLocationDraft?> read() async {
    final draft = await store.read();
    if (draft == null) return null;
    final location = ChatLocation.tryParse(jsonDecode(draft.text));
    if (location == null) throw const FormatException('Invalid location draft');
    return ChatLocationDraft(draft.id, location);
  }

  Future<ChatLocationDraft> save(ChatLocation location) async {
    final draft = ChatTextDraft(jsonEncode(location.toJson()));
    await store.write(draft);
    return ChatLocationDraft(draft.id, location);
  }

  Future<void> remove(String id) => store.remove(id);
}
