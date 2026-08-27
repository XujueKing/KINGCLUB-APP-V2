import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'contact_selector_page.dart';
import 'direct_chat_details_page.dart';
import 'legacy_messaging_components.dart';

enum _FakeMessageStatus { sending, sent, failed }

enum _FakeMessageKind { text, image, video, businessCard }

enum _FakeMessageAction { copy, quote, forward, delete, recall }

class DirectChatPage extends StatefulWidget {
  const DirectChatPage({super.key, this.peerName = '卡座搭子'});

  final String peerName;

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _attachmentsOpen = false;
  String? _quotedDraft;
  final bool _readOnly = false;
  late final List<_FakeMessage> _messages = [
    _FakeMessage(
      '你已添加了${widget.peerName}，现在可以开始聊天了。',
      mine: false,
      system: true,
    ),
    const _FakeMessage('周末 KING CLUB 见？', mine: false),
    const _FakeMessage('好，晚上九点。', mine: true),
    const _FakeMessage('A6 卡座见', mine: false, quoted: '好，晚上九点。'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: widget.peerName,
              onBack: () => Navigator.pop(context),
              trailing: IconButton(
                key: const ValueKey('direct-chat-details'),
                tooltip: '聊天详情',
                onPressed: _openDetails,
                icon: const Icon(Icons.more_horiz, color: legacyMessageGold),
              ),
            ),
            if (_readOnly)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(9),
                color: const Color(0x221F1B17),
                child: const Text(
                  '好友关系已结束，历史记录仅可查看',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                ),
              ),
            Expanded(
              child: ListView.builder(
                key: const ValueKey('direct-chat-message-list'),
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text(
                        '今天 21:08',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0x66777777),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  final messageIndex = index - 1;
                  return _MessageRow(
                    message: _messages[messageIndex],
                    onRetry: () => setState(
                      () => _messages[messageIndex] = _messages[messageIndex]
                          .copyWith(status: _FakeMessageStatus.sent),
                    ),
                    onLongPress: () => _showMessageMenu(messageIndex),
                    onTap: () => _openMediaPreview(_messages[messageIndex]),
                  );
                },
              ),
            ),
            _composer(),
            SizedBox(
              height: _attachmentsOpen && !_readOnly ? 112 : 0,
              child: _attachmentsOpen && !_readOnly
                  ? ColoredBox(
                      color: legacyMessagePanel,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _AttachmentAction(
                            icon: Icons.image_outlined,
                            label: '图片',
                            onTap: () => _addAttachment(_FakeMessageKind.image),
                          ),
                          _AttachmentAction(
                            icon: Icons.videocam_outlined,
                            label: '短视频',
                            onTap: () => _addAttachment(_FakeMessageKind.video),
                          ),
                          _AttachmentAction(
                            icon: Icons.confirmation_number_outlined,
                            label: '业务卡片',
                            onTap: () =>
                                _addAttachment(_FakeMessageKind.businessCard),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      color: legacyMessagePanel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_quotedDraft != null)
            Container(
              key: const ValueKey('direct-chat-quote-draft'),
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(58, 8, 14, 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF27221E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _quotedDraft!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0x99C9B69E),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('direct-chat-close-quote'),
                    tooltip: '取消引用',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _quotedDraft = null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('direct-chat-attachments'),
                  onPressed: _readOnly
                      ? null
                      : () => setState(
                          () => _attachmentsOpen = !_attachmentsOpen,
                        ),
                  icon: Icon(
                    _attachmentsOpen ? Icons.close : Icons.add_circle_outline,
                    color: legacyMessageGold,
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('direct-chat-input'),
                    controller: _controller,
                    enabled: !_readOnly,
                    minLines: 1,
                    maxLines: 4,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: _readOnly ? '当前不可发送消息' : '发消息',
                      filled: true,
                      fillColor: const Color(0xFF312C27),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) => TextButton(
                    key: const ValueKey('direct-chat-send'),
                    onPressed: _readOnly || value.text.trim().isEmpty
                        ? null
                        : _send,
                    child: const Text('发送'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _readOnly) return;
    final message = _FakeMessage(
      text,
      mine: true,
      quoted: _quotedDraft,
      status: text == '失败'
          ? _FakeMessageStatus.failed
          : _FakeMessageStatus.sending,
    );
    setState(() {
      _messages.add(message);
      _controller.clear();
      _quotedDraft = null;
      _attachmentsOpen = false;
    });
    _scrollToLatest();
    if (message.status == _FakeMessageStatus.sending) _completeSend(message);
  }

  void _addAttachment(_FakeMessageKind kind) {
    final message = switch (kind) {
      _FakeMessageKind.image => const _FakeMessage(
        '现场照片',
        mine: true,
        kind: _FakeMessageKind.image,
        assetPath: 'assets/legacy/home/mock_poster_music.png',
        status: _FakeMessageStatus.sending,
      ),
      _FakeMessageKind.video => const _FakeMessage(
        '现场短视频',
        mine: true,
        kind: _FakeMessageKind.video,
        assetPath: 'assets/legacy/home/mock_hero_recruitment.png',
        status: _FakeMessageStatus.sending,
      ),
      _FakeMessageKind.businessCard => const _FakeMessage(
        '星光香槟套餐',
        mine: true,
        kind: _FakeMessageKind.businessCard,
        status: _FakeMessageStatus.sending,
      ),
      _FakeMessageKind.text => throw StateError('Text uses the composer.'),
    };
    setState(() {
      _messages.add(message);
      _attachmentsOpen = false;
    });
    _scrollToLatest();
    _completeSend(message);
  }

  Future<void> _completeSend(_FakeMessage message) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;
    final index = _messages.indexWhere((item) => identical(item, message));
    if (index == -1) return;
    setState(() {
      _messages[index] = message.copyWith(status: _FakeMessageStatus.sent);
    });
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openDetails() async {
    final cleared = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => DirectChatDetailsPage(peerName: widget.peerName),
      ),
    );
    if (cleared == true && mounted) setState(_messages.clear);
  }

  Future<void> _showMessageMenu(int index) async {
    final message = _messages[index];
    final action = await showModalBottomSheet<_FakeMessageAction>(
      context: context,
      backgroundColor: legacyMessagePanel,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (message.kind == _FakeMessageKind.text)
              ListTile(
                key: const ValueKey('direct-chat-copy'),
                leading: const Icon(Icons.copy_outlined),
                title: const Text('复制'),
                onTap: () =>
                    Navigator.pop(sheetContext, _FakeMessageAction.copy),
              ),
            ListTile(
              leading: const Icon(Icons.format_quote),
              title: const Text('引用'),
              onTap: () =>
                  Navigator.pop(sheetContext, _FakeMessageAction.quote),
            ),
            ListTile(
              key: const ValueKey('direct-chat-forward'),
              leading: const Icon(Icons.forward),
              title: const Text('转发'),
              onTap: () =>
                  Navigator.pop(sheetContext, _FakeMessageAction.forward),
            ),
            ListTile(
              key: const ValueKey('direct-chat-delete'),
              leading: const Icon(Icons.delete_outline),
              title: const Text('为我删除'),
              onTap: () =>
                  Navigator.pop(sheetContext, _FakeMessageAction.delete),
            ),
            if (message.mine)
              ListTile(
                key: const ValueKey('direct-chat-recall'),
                leading: const Icon(Icons.undo),
                title: const Text('撤回'),
                onTap: () =>
                    Navigator.pop(sheetContext, _FakeMessageAction.recall),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FakeMessageAction.copy:
        Clipboard.setData(ClipboardData(text: message.text));
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已复制')));
      case _FakeMessageAction.quote:
        setState(() => _quotedDraft = _messagePreview(message));
      case _FakeMessageAction.forward:
        await Navigator.push<bool>(
          context,
          MaterialPageRoute<bool>(
            builder: (_) => ContactSelectorPage(preview: message.text),
          ),
        );
      case _FakeMessageAction.delete:
        final confirmed = await _confirmMessageAction(
          title: '删除这条消息？',
          action: '删除',
          body: '只会从当前设备的 Fake 会话中移除。',
        );
        if (confirmed && mounted && index < _messages.length) {
          setState(() => _messages.removeAt(index));
        }
      case _FakeMessageAction.recall:
        final confirmed = await _confirmMessageAction(
          title: '撤回这条消息？',
          action: '撤回',
          body: '撤回后可重新编辑文字消息。',
        );
        if (confirmed && mounted && index < _messages.length) {
          setState(() {
            _messages[index] = const _FakeMessage(
              '你撤回了一条消息',
              mine: true,
              system: true,
            );
          });
        }
    }
  }

  String _messagePreview(_FakeMessage message) => switch (message.kind) {
    _FakeMessageKind.text => message.text,
    _FakeMessageKind.image => '[图片]',
    _FakeMessageKind.video => '[短视频]',
    _FakeMessageKind.businessCard => '[业务卡片] ${message.text}',
  };

  Future<bool> _confirmMessageAction({
    required String title,
    required String action,
    required String body,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: legacyMessagePanel,
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: ValueKey('direct-chat-confirm-$action'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _openMediaPreview(_FakeMessage message) async {
    if (message.kind != _FakeMessageKind.image &&
        message.kind != _FakeMessageKind.video) {
      return;
    }
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) => Material(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.asset(
                    message.assetPath!,
                    key: const ValueKey('direct-chat-media-preview'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: const ValueKey('direct-chat-close-media'),
                  tooltip: '关闭预览',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              if (message.kind == _FakeMessageKind.video)
                const Center(
                  child: Icon(
                    Icons.play_circle_fill,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.onRetry,
    required this.onLongPress,
    required this.onTap,
  });

  final _FakeMessage message;
  final VoidCallback onRetry;
  final VoidCallback onLongPress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (message.system) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          message.text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0x66777777), fontSize: 12),
        ),
      );
    }
    final isMedia =
        message.kind == _FakeMessageKind.image ||
        message.kind == _FakeMessageKind.video;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: message.mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!message.mine) ...[
                const LegacyFakeAvatar(size: 42),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: GestureDetector(
                  onLongPress: onLongPress,
                  onTap: onTap,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 280),
                    padding: isMedia
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: isMedia
                          ? Colors.transparent
                          : message.mine
                          ? const Color(0xFF29B463)
                          : const Color(0x33C9B69E),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.quoted != null) ...[
                          Text(
                            message.quoted!,
                            style: TextStyle(
                              color: message.mine
                                  ? const Color(0x99111111)
                                  : const Color(0x99C9B69E),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 5),
                        ],
                        _MessageContent(message: message),
                      ],
                    ),
                  ),
                ),
              ),
              if (message.mine) ...[
                const SizedBox(width: 10),
                const LegacyFakeAvatar(size: 42),
              ],
            ],
          ),
          if (message.status == _FakeMessageStatus.failed)
            TextButton.icon(
              key: const ValueKey('direct-chat-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.error_outline, size: 15),
              label: const Text('发送失败，重试'),
            )
          else if (message.status == _FakeMessageStatus.sending)
            const Padding(
              padding: EdgeInsets.only(top: 4, right: 52),
              child: Text(
                '发送中…',
                style: TextStyle(color: Color(0x66777777), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message});

  final _FakeMessage message;

  @override
  Widget build(BuildContext context) {
    switch (message.kind) {
      case _FakeMessageKind.text:
        return Text(
          message.text,
          style: TextStyle(
            color: message.mine ? const Color(0xFF222222) : legacyMessageGold,
            fontSize: 15,
          ),
        );
      case _FakeMessageKind.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Image.asset(
            message.assetPath!,
            key: const ValueKey('direct-chat-image-message'),
            width: 142,
            height: 180,
            fit: BoxFit.cover,
          ),
        );
      case _FakeMessageKind.video:
        return Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.asset(
                message.assetPath!,
                key: const ValueKey('direct-chat-video-message'),
                width: 172,
                height: 112,
                fit: BoxFit.cover,
              ),
            ),
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 42),
          ],
        );
      case _FakeMessageKind.businessCard:
        return SizedBox(
          key: const ValueKey('direct-chat-business-card-message'),
          width: 218,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1611),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.confirmation_number_outlined,
                      color: legacyMessageGold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: const TextStyle(
                            color: Color(0xFF222222),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          '08月29日 · KING CLUB',
                          style: TextStyle(
                            color: Color(0x99111111),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: Color(0x33222222)),
              const SizedBox(height: 6),
              const Text(
                '入场凭证 · UI Mock',
                style: TextStyle(color: Color(0x99111111), fontSize: 10),
              ),
            ],
          ),
        );
    }
  }
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF312C27),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: legacyMessageGold),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakeMessage {
  const _FakeMessage(
    this.text, {
    required this.mine,
    this.quoted,
    this.system = false,
    this.kind = _FakeMessageKind.text,
    this.assetPath,
    this.status = _FakeMessageStatus.sent,
  });

  final String text;
  final bool mine;
  final String? quoted;
  final bool system;
  final _FakeMessageKind kind;
  final String? assetPath;
  final _FakeMessageStatus status;

  _FakeMessage copyWith({_FakeMessageStatus? status}) => _FakeMessage(
    text,
    mine: mine,
    quoted: quoted,
    system: system,
    kind: kind,
    assetPath: assetPath,
    status: status ?? this.status,
  );
}
