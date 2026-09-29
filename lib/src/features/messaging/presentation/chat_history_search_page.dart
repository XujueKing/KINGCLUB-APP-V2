import '../data/chat_history_access.dart';
import '../data/chat_history_label.dart';

import 'dart:async';

import 'chat_timestamp.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/chat_history_store.dart';
import '../data/chat_media_event_scope.dart';
import '../data/chat_media_deletion.dart';

import 'package:flutter/material.dart';

import '../../../core/networking/kingclub_realtime.dart';
import '../../../core/session/secure_session_store.dart';

typedef HistorySearch = Future<Map<String, dynamic>> Function(
  String query,
  int? before,
);

class ChatHistorySearchPage extends StatefulWidget {
  const ChatHistorySearchPage({
    super.key,
    required this.search,
    this.events,
    this.onSelected,
    this.senderLabel,
    this.groupId,
    this.mediaSearch,
    this.account,
    this.localConversation,
    this.historyRemovals,
    this.localSearch,
  });
  final HistorySearch search;

  /// Account-scoped local lookup; the default uses encrypted persisted history.
  final Future<Map<String, dynamic>> Function(
    String query,
    int? before,
    String? messageType,
  )?
  localSearch;
  final HistorySearch? mediaSearch;
  final String? groupId;
  final String? account;
  final String? localConversation;

  /// Must belong to [account], like the default account-scoped history store.
  final Stream<ConversationHistoryRemoval>? historyRemovals;
  final String Function(String account)? senderLabel;
  final ValueChanged<Map<String, dynamic>>? onSelected;
  final Stream<Map<String, dynamic>>? events;
  @override
  State<ChatHistorySearchPage> createState() => _ChatHistorySearchPageState();
}

class _ChatHistorySearchPageState extends State<ChatHistorySearchPage>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _items = <Map<String, dynamic>>[];
  StreamSubscription<void>? _session;
  StreamSubscription<Map<String, dynamic>>? _events;
  StreamSubscription<ConversationHistoryRemoval>? _historyRemovals;
  late final Future<void> _watchingHistory;
  void Function()? _stopDeletion;
  final _removedIds = <String>{};
  final _removedSequences = <int>{};
  int _hiddenThrough = 0;
  Timer? _debounce;
  int _generation = 0;
  int? _before;
  bool _busy = false, _invalid = false, _foreground = true;
  String? _error;
  String? _messageType;
  bool _localOnly = false;
  bool get _hasCriteria =>
      _messageType != null || _input.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _watchingHistory = _watchHistory();
    _stopDeletion = ChatMediaDeletion.listen((event) {
      if (_invalid ||
          event.account != widget.account ||
          event.group != (widget.groupId != null)) {
        return;
      }
      _removedIds.add(event.messageId);
      if (_busy || _items.any((row) => row['messageId'] == event.messageId)) {
        _changed();
      }
    });
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _input.clear();
      _clear();
      if (mounted) setState(() => _error = '登录状态已变化');
    });
    _events = (widget.events ?? KingclubRealtime.shared.events).listen((event) {
      if (affectsChatMedia(
            event,
            group: widget.groupId != null,
            scopeId: widget.groupId,
          ) ||
          (widget.groupId == null &&
              event['eventType'] == 'chat.read.changed')) {
        _changed();
      }
    });
  }

  Future<void> _watchHistory() async {
    if (widget.localConversation == null || widget.account == null) return;
    try {
      final stream =
          widget.historyRemovals ??
          (await ChatHistoryStore.open(widget.account!)).clearedConversations;
      if (!mounted || _invalid) return;
      _historyRemovals = stream.listen((removal) {
        if (_invalid || removal.conversation != widget.localConversation) {
          return;
        }
        if (removal.hiddenThrough > _hiddenThrough) {
          _hiddenThrough = removal.hiddenThrough;
        }
        final sequences = removal.sequences;
        if (sequences == null) {
          // A full clear includes remote search rows not yet saved on disk.
          // Cancel the old query instead of reissuing it during clear handling.
          _input.clear();
          _messageType = null;
          _clear();
          setState(() {});
        } else {
          _removedSequences.addAll(sequences);
          _changed();
        }
      });
    } catch (_) {
      // Local storage failure does not grant offline access or stop a valid
      // remote search; normal query error handling remains authoritative.
    }
  }

  void _clear() {
    _debounce?.cancel();
    _generation++;
    _items.clear();
    _before = null;
    _busy = false;
    _error = null;
    _localOnly = false;
  }

  void _changed() {
    _clear();
    if (mounted) {
      setState(() {});
    }
    if (!_invalid && _foreground && _hasCriteria) {
      _debounce = Timer(const Duration(milliseconds: 300), () => _load());
    }
  }

  Future<void> _load({bool more = false}) async {
    final query = _input.text.trim();
    final messageType = _messageType;
    if (_invalid ||
        !_foreground ||
        _busy ||
        !_hasCriteria ||
        (more && _before == null)) {
      return;
    }
    final generation = ++_generation;
    final before = more ? _before : null;
    setState(() {
      _busy = true;
      _error = null;
    });
    var remoteFinished = false;
    try {
      await _watchingHistory;
      if (!mounted || _invalid || generation != _generation) return;
      Future<Map<String, dynamic>> localSearch() async {
        if (widget.localSearch != null) {
          return widget.localSearch!(query, before, messageType);
        }
        final store = await ChatHistoryStore.open(widget.account!);
        return store.search(
          widget.localConversation!,
          query: query,
          messageType: messageType,
          before: before,
          isActive: () =>
              mounted &&
              !_invalid &&
              _foreground &&
              generation == _generation &&
              !remoteFinished,
        );
      }

      Future<Map<String, dynamic>>? preview;
      if (!more && widget.account != null && widget.localConversation != null) {
        preview = localSearch();
        unawaited(
          preview
              .then((cached) {
                if (!mounted ||
                    _invalid ||
                    generation != _generation ||
                    remoteFinished) {
                  return;
                }
                _applyResult(
                  {...cached, 'localOnly': true},
                  more: false,
                  before: null,
                  messageType: messageType,
                  loading: true,
                );
              })
              .catchError((Object _) {
                // Missing/corrupt local storage must not suppress a valid remote query.
              }),
        );
      }
      Map<String, dynamic> result;
      if (more && _localOnly) {
        result = await localSearch();
      } else {
        try {
          result = messageType == null
              ? await widget.search(query, before)
              : await widget.mediaSearch!(messageType, before);
        } on AuthFailure catch (error) {
          if (error.code != 'NETWORK_ERROR' ||
              widget.account == null ||
              widget.localConversation == null) {
            rethrow;
          }
          result = await (preview ?? localSearch());
        }
      }
      if (!mounted || generation != _generation) {
        return;
      }
      remoteFinished = true;
      _applyResult(
        result,
        more: more,
        before: before,
        messageType: messageType,
      );
    } catch (error) {
      remoteFinished = true;
      if (!mounted || generation != _generation) {
        return;
      }
      setState(() {
        _items.clear();
        _before = null;
        _busy = false;
        _error = '搜索未完成，请重试';
      });
      if (widget.account != null && widget.groupId != null) {
        try {
          await clearDeniedGroupHistory(
            error,
            account: widget.account!,
            groupId: widget.groupId,
          );
        } catch (_) {
          // Keep the denied/error presentation even if local cleanup fails.
        }
      }
    } finally {
      remoteFinished = true;
    }
  }

  void _applyResult(
    Map<String, dynamic> result, {
    required bool more,
    required int? before,
    required String? messageType,
    bool loading = false,
  }) {
    final raw = result['messages'];
    if (raw is! List || result['hasMore'] is! bool) {
      throw const FormatException('Invalid search result');
    }
    final page = raw
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
    var previous = 0;
    for (final row in page) {
      final sequence = row['sequence'];
      if (sequence is! int ||
          sequence <= previous ||
          (before != null && sequence >= before) ||
          row['messageId'] is! String ||
          row['text'] is! String ||
          row['sender'] is! String) {
        throw const FormatException('Invalid search message');
      }
      if (messageType != null && row['messageType'] != messageType) {
        throw const FormatException('Unexpected media search result');
      }
      previous = sequence;
    }
    if (result['hasMore'] == true && page.isEmpty) {
      throw const FormatException('Invalid search cursor');
    }
    setState(() {
      _localOnly = result['localOnly'] == true;
      if (!more) {
        _items.clear();
      }
      _items.addAll(
        page.reversed.where(
          (row) =>
              !_removedIds.contains(row['messageId']) &&
              !_removedSequences.contains(row['sequence']) &&
              (row['sequence'] as int) > _hiddenThrough &&
              !const {'hidden', 'recalled'}.contains(row['messageType']),
        ),
      );
      _before = result['hasMore'] == true
          ? page.first['sequence'] as int
          : null;
      _busy = loading;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _changed();
  }

  @override
  void dispose() {
    _clear();
    _session?.cancel();
    _events?.cancel();
    _historyRemovals?.cancel();
    _stopDeletion?.call();
    WidgetsBinding.instance.removeObserver(this);
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF111111),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('chat-history-search-input'),
                    controller: _input,
                    enabled: !_invalid,
                    autofocus: true,
                    maxLength: 100,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: (_) {
                      _messageType = null;
                      _changed();
                    },
                    onSubmitted: (_) {
                      _debounce?.cancel();
                      _load();
                    },
                    decoration: InputDecoration(
                      hintText: '搜索',
                      counterText: '',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF777777),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF191919),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Color(0xFF8996A5), fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          if (widget.mediaSearch != null && _input.text.trim().isEmpty)
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Column(
                    children: [
                      const Text(
                        '快速搜索聊天内容',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 22),
                      for (final row in const [
                        [('image', '图片'), ('video', '视频'), ('file', '文件')],
                        [('voice', '音频'), ('location', '位置')],
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              for (var i = 0; i < row.length; i++) ...[
                                if (i > 0)
                                  const SizedBox(
                                    height: 20,
                                    child: VerticalDivider(
                                      width: 1,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                Expanded(
                                  child: TextButton(
                                    key: ValueKey('history-type-${row[i].$1}'),
                                    onPressed: _invalid
                                        ? null
                                        : () {
                                            FocusScope.of(context).unfocus();
                                            _input.clear();
                                            _messageType = row[i].$1;
                                            _changed();
                                          },
                                    child: Text(
                                      row[i].$2,
                                      style: const TextStyle(
                                        color: Color(0xFF8996A5),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              if (row.length < 3)
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (_localOnly)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '当前仅搜索本机已保存的记录',
                style: TextStyle(color: Color(0x88FFFFFF), fontSize: 12),
              ),
            ),
          Expanded(
            child: !_foreground
                ? const SizedBox.shrink()
                : _error != null
                ? Center(
                    child: TextButton(
                      onPressed: _invalid ? null : () => _load(),
                      child: Text(_error!),
                    ),
                  )
                : _items.isEmpty
                ? Center(
                    child: Text(
                      _busy
                          ? '正在搜索…'
                          : !_hasCriteria
                          ? ''
                          : '未找到相关聊天内容',
                      style: const TextStyle(color: Color(0x88FFFFFF)),
                    ),
                  )
                : ListView.separated(
                    itemCount: _items.length + (_before != null ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 20,
                      endIndent: 20,
                      color: Color(0x14FFFFFF),
                    ),
                    itemBuilder: (_, index) {
                      if (index == _items.length) {
                        return TextButton(
                          onPressed: _busy ? null : () => _load(more: true),
                          child: Text(_busy ? '正在搜索…' : '加载更早结果'),
                        );
                      }
                      final row = _items[index];
                      final date = chatTimestampLabel(
                        row['createdDate']?.toString(),
                        null,
                      );
                      return ListTile(
                        onTap: widget.onSelected == null
                            ? null
                            : () => widget.onSelected!(row),
                        title: Text(
                          chatHistoryLabel(row),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          [
                            widget.senderLabel?.call(row['sender'] as String) ??
                                row['sender'] as String,
                            ?date,
                          ].where((part) => part.isNotEmpty).join(' · '),
                          style: const TextStyle(
                            color: Color(0x88FFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
