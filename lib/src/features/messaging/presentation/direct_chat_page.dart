import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';

import 'contact_selector_page.dart';
import 'direct_chat_details_page.dart';
import 'legacy_messaging_components.dart';

enum _FakeMessageStatus { sending, sent, failed }

enum _FakeMessageKind {
  text,
  image,
  video,
  businessCard,
  goldCoin,
  redPacket,
  gift,
}

enum _ComposerPanel { none, attachments, gifts }

enum _FakeMessageAction { copy, quote, forward, delete, recall }

const _giftItems = <_GiftItem>[
  _GiftItem(
    id: 0,
    name: '星光玫瑰',
    price: 599,
    category: 2,
    assetPath: 'assets/legacy/messaging/gift_rose.png',
  ),
  _GiftItem(
    id: 1,
    name: '冲刺狂王',
    price: 1200,
    category: 1,
    assetPath: 'assets/legacy/messaging/gift_racer.png',
  ),
  _GiftItem(
    id: 2,
    name: '变形战车',
    price: 2999,
    category: 1,
    assetPath: 'assets/legacy/messaging/gift_transformer.png',
  ),
  _GiftItem(
    id: 3,
    name: '嘉年华',
    price: 30000,
    category: 1,
    assetPath: 'assets/legacy/messaging/gift_anniversary.png',
  ),
  _GiftItem(
    id: 4,
    name: '夏日度假',
    price: 999,
    category: 3,
    assetPath: 'assets/legacy/messaging/gift_flamingo.png',
  ),
  _GiftItem(
    id: 5,
    name: '天鹅之梦',
    price: 50,
    category: 2,
    assetPath: 'assets/legacy/messaging/gift_swan.png',
  ),
  _GiftItem(
    id: 6,
    name: '天鹅公主',
    price: 999,
    category: 2,
    assetPath: 'assets/legacy/messaging/gift_princess.png',
  ),
  _GiftItem(
    id: 7,
    name: '太空之镜',
    price: 6399,
    category: 3,
    assetPath: 'assets/legacy/messaging/gift_horse.png',
  ),
];

class _GiftItem {
  const _GiftItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.assetPath,
  });

  final int id;
  final String name;
  final int price;
  final int category;
  final String assetPath;
}

class DirectChatPage extends StatefulWidget {
  const DirectChatPage({super.key, this.peerName = '卡座搭子'});

  final String peerName;

  @override
  State<DirectChatPage> createState() => _DirectChatPageState();
}

class _DirectChatPageState extends State<DirectChatPage>
    with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  final _attachmentPageController = PageController();
  Timer? _keyboardScrollDebounce;
  bool _scrollScheduled = false;
  _ComposerPanel _composerPanel = _ComposerPanel.none;
  int _attachmentPage = 0;
  int _giftCategory = 0;
  int? _selectedGift;
  int _goldBalance = 501;
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inputFocusNode.addListener(_handleInputFocusChanged);
  }

  @override
  void didChangeMetrics() {
    _keyboardScrollDebounce?.cancel();
    _keyboardScrollDebounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted || !_inputFocusNode.hasFocus) return;
      if (View.of(context).viewInsets.bottom <= 0) return;
      _scrollToLatest();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardScrollDebounce?.cancel();
    _inputFocusNode
      ..removeListener(_handleInputFocusChanged)
      ..dispose();
    _controller.dispose();
    _scrollController.dispose();
    _attachmentPageController.dispose();
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
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                scrollCacheExtent: const ScrollCacheExtent.pixels(640),
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
                          color: Color(0x998A8178),
                          fontSize: 12,
                        ),
                      ),
                    );
                  }
                  final messageIndex = index - 1;
                  final message = _messages[messageIndex];
                  return RepaintBoundary(
                    key: ObjectKey(message),
                    child: _MessageRow(
                      message: message,
                      onRetry: () => setState(
                        () => _messages[messageIndex] = _messages[messageIndex]
                            .copyWith(status: _FakeMessageStatus.sent),
                      ),
                      onLongPress: () => _showMessageMenu(messageIndex),
                      onTap: () => _openMediaPreview(message),
                    ),
                  );
                },
              ),
            ),
            _composer(),
            if (!_readOnly) _activeComposerPanel(),
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
                  key: const ValueKey('direct-chat-gifts'),
                  tooltip: '礼物',
                  onPressed: _readOnly ? null : _toggleGifts,
                  icon: Image.asset(
                    'assets/legacy/messaging/gift2.png',
                    width: 30,
                    height: 30,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                Expanded(
                  child: TextField(
                    key: const ValueKey('direct-chat-input'),
                    controller: _controller,
                    focusNode: _inputFocusNode,
                    enabled: !_readOnly,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
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
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, _) {
                    final enabled = !_readOnly && value.text.trim().isNotEmpty;
                    if (enabled) {
                      return SizedBox(
                        width: 58,
                        height: 40,
                        child: TextButton(
                          key: const ValueKey('direct-chat-send'),
                          onPressed: _send,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFF07C160),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('发送'),
                        ),
                      );
                    }
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: const ValueKey('direct-chat-emoji'),
                          tooltip: '表情',
                          visualDensity: VisualDensity.compact,
                          onPressed: _insertEmoji,
                          icon: Image.asset(
                            'assets/legacy/messaging/smail.png',
                            width: 29,
                            height: 29,
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('direct-chat-attachments'),
                          tooltip: '更多',
                          visualDensity: VisualDensity.compact,
                          onPressed: _toggleAttachments,
                          icon: Image.asset(
                            'assets/legacy/messaging/add.png',
                            width: 29,
                            height: 29,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeComposerPanel() {
    return switch (_composerPanel) {
      _ComposerPanel.none => const SizedBox.shrink(),
      _ComposerPanel.attachments => _attachmentPanel(),
      _ComposerPanel.gifts => _giftPanel(),
    };
  }

  Widget _attachmentPanel() {
    return Container(
      key: const ValueKey('direct-chat-attachment-panel'),
      height: 178,
      width: double.infinity,
      color: legacyMessagePanel,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _attachmentPageController,
              onPageChanged: (value) => setState(() => _attachmentPage = value),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentAction(
                      assetPath: 'assets/legacy/messaging/more_1.png',
                      label: '照片',
                      onTap: () => _addAttachment(_FakeMessageKind.image),
                    ),
                    _AttachmentAction(
                      assetPath: 'assets/legacy/messaging/more_2.png',
                      label: '拍照',
                      onTap: _takeFakePhoto,
                    ),
                    _AttachmentAction(
                      assetPath: 'assets/legacy/messaging/more_3.png',
                      label: '金币',
                      onTap: _openGoldCoinComposer,
                    ),
                    _AttachmentAction(
                      assetPath: 'assets/legacy/messaging/more_4.png',
                      label: '红包',
                      onTap: _openRedPacketComposer,
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 15),
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
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              2,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _attachmentPage
                      ? legacyMessageGold
                      : const Color(0x55777777),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _giftPanel() {
    const categories = ['推荐', '场景特效', '爱意表达', '装饰互动'];
    final visible = _giftCategory == 0
        ? _giftItems
        : _giftItems
              .where((item) => item.category == _giftCategory)
              .toList(growable: false);
    return Container(
      key: const ValueKey('direct-chat-gift-panel'),
      height: 326,
      width: double.infinity,
      color: const Color(0xFF171513),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 16),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => ChoiceChip(
                      key: ValueKey('direct-chat-gift-category-$index'),
                      label: Text(categories[index]),
                      selected: _giftCategory == index,
                      onSelected: (_) => setState(() {
                        _giftCategory = index;
                        _selectedGift = null;
                      }),
                      showCheckmark: false,
                      backgroundColor: Colors.transparent,
                      selectedColor: const Color(0xFF342E28),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: _giftCategory == index
                            ? legacyMessageGold
                            : const Color(0xFFB3AAA2),
                        fontSize: 12,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(right: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2520),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/legacy/messaging/gold.png',
                        width: 17,
                        height: 17,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_goldBalance',
                        style: TextStyle(
                          color: legacyMessageGold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x332F2A25)),
          Expanded(
            child: GridView.builder(
              key: const ValueKey('direct-chat-gift-grid'),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 0.78,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final item = visible[index];
                final selected = _selectedGift == item.id;
                return InkWell(
                  key: ValueKey('direct-chat-gift-${item.id}'),
                  onTap: () => setState(() => _selectedGift = item.id),
                  borderRadius: BorderRadius.circular(8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF2E2924)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Image.asset(
                            item.assetPath,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        if (selected)
                          SizedBox(
                            width: double.infinity,
                            height: 24,
                            child: FilledButton(
                              key: ValueKey('direct-chat-gift-send-${item.id}'),
                              onPressed: () => _sendGift(item),
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: legacyMessageGold,
                                foregroundColor: const Color(0xFF24180A),
                                shape: const RoundedRectangleBorder(),
                                textStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('赠送'),
                            ),
                          )
                        else ...[
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB8B0A8),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${item.price} 币',
                            style: const TextStyle(
                              color: Color(0xFF6F6963),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
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
      _composerPanel = _ComposerPanel.none;
    });
    _scrollToLatest();
    if (message.status == _FakeMessageStatus.sending) _completeSend(message);
  }

  void _handleInputFocusChanged() {
    if (!_inputFocusNode.hasFocus || _composerPanel == _ComposerPanel.none) {
      return;
    }
    setState(() => _composerPanel = _ComposerPanel.none);
  }

  void _toggleAttachments() {
    final opening = _composerPanel != _ComposerPanel.attachments;
    if (opening) _inputFocusNode.unfocus();
    setState(() {
      _composerPanel = opening
          ? _ComposerPanel.attachments
          : _ComposerPanel.none;
      if (opening) _selectedGift = null;
    });
    if (opening) _scrollToLatest();
  }

  void _toggleGifts() {
    final opening = _composerPanel != _ComposerPanel.gifts;
    if (opening) _inputFocusNode.unfocus();
    setState(() {
      _composerPanel = opening ? _ComposerPanel.gifts : _ComposerPanel.none;
      _selectedGift = null;
    });
    if (opening) _scrollToLatest();
  }

  void _insertEmoji() {
    _controller
      ..text = '${_controller.text}😀'
      ..selection = TextSelection.collapsed(offset: _controller.text.length);
    _inputFocusNode.requestFocus();
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
      _FakeMessageKind.goldCoin ||
      _FakeMessageKind.redPacket ||
      _FakeMessageKind.gift => throw StateError('Use the dedicated composer.'),
    };
    setState(() {
      _messages.add(message);
      _composerPanel = _ComposerPanel.none;
    });
    _scrollToLatest();
    _completeSend(message);
  }

  void _takeFakePhoto() {
    const message = _FakeMessage(
      '刚刚拍摄',
      mine: true,
      kind: _FakeMessageKind.image,
      assetPath: 'assets/legacy/home/mock_hero_recruitment.png',
      status: _FakeMessageStatus.sending,
    );
    _appendFakeMessage(message);
  }

  Future<void> _openGoldCoinComposer() async {
    setState(() => _composerPanel = _ComposerPanel.none);
    final amount = await _showNumberComposer(
      title: '转赠金币',
      helper: '当前可用 $_goldBalance 金币',
      action: '确认赠送',
      max: _goldBalance,
    );
    if (!mounted || amount == null) return;
    setState(() => _goldBalance -= amount);
    _appendFakeMessage(
      _FakeMessage(
        '$amount 枚',
        mine: true,
        kind: _FakeMessageKind.goldCoin,
        status: _FakeMessageStatus.sending,
      ),
    );
  }

  Future<void> _openRedPacketComposer() async {
    setState(() => _composerPanel = _ComposerPanel.none);
    final amount = await _showNumberComposer(
      title: '发红包',
      helper: '本地 Mock，不会产生真实扣款',
      action: '塞钱进红包',
      max: 200,
      suffix: '元',
    );
    if (!mounted || amount == null) return;
    _appendFakeMessage(
      _FakeMessage(
        '恭喜发财 · ¥$amount.00',
        mine: true,
        kind: _FakeMessageKind.redPacket,
        status: _FakeMessageStatus.sending,
      ),
    );
  }

  Future<int?> _showNumberComposer({
    required String title,
    required String helper,
    required String action,
    required int max,
    String suffix = '枚',
  }) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF171513),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          22,
          24,
          24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: legacyMessageGold,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              helper,
              style: const TextStyle(color: Color(0xFF8A8178), fontSize: 12),
            ),
            const SizedBox(height: 18),
            TextField(
              key: ValueKey('direct-chat-$title-input'),
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white, fontSize: 22),
              decoration: InputDecoration(
                hintText: '请输入数量',
                suffixText: suffix,
                filled: true,
                fillColor: const Color(0xFF312C27),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              key: ValueKey('direct-chat-$title-confirm'),
              onPressed: () {
                final value = int.tryParse(controller.text);
                if (value == null || value <= 0 || value > max) return;
                Navigator.pop(sheetContext, value);
              },
              style: FilledButton.styleFrom(
                backgroundColor: legacyMessageGold,
                foregroundColor: const Color(0xFF24180A),
                shape: const StadiumBorder(),
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  void _sendGift(_GiftItem item) {
    if (item.price > _goldBalance) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('金币不足，还差 ${item.price - _goldBalance} 枚')),
        );
      return;
    }
    setState(() {
      _goldBalance -= item.price;
      _selectedGift = null;
    });
    _appendFakeMessage(
      _FakeMessage(
        item.name,
        mine: true,
        kind: _FakeMessageKind.gift,
        assetPath: item.assetPath,
        status: _FakeMessageStatus.sending,
      ),
    );
  }

  void _appendFakeMessage(_FakeMessage message) {
    setState(() {
      _messages.add(message);
      _composerPanel = _ComposerPanel.none;
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
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if ((_scrollController.position.pixels - target).abs() < 1) return;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
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
    _FakeMessageKind.goldCoin => '[金币] ${message.text}',
    _FakeMessageKind.redPacket => '[红包] ${message.text}',
    _FakeMessageKind.gift => '[礼物] ${message.text}',
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
          style: const TextStyle(color: Color(0x998A8178), fontSize: 12),
        ),
      );
    }
    final isMedia =
        message.kind == _FakeMessageKind.image ||
        message.kind == _FakeMessageKind.video;
    final isVisualCard =
        isMedia ||
        message.kind == _FakeMessageKind.goldCoin ||
        message.kind == _FakeMessageKind.redPacket ||
        message.kind == _FakeMessageKind.gift;
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
                    padding: isVisualCard
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                    decoration: BoxDecoration(
                      color: isVisualCard
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
      case _FakeMessageKind.goldCoin:
        return _LegacyValueMessageCard(
          key: const ValueKey('direct-chat-gold-message'),
          assetPath: 'assets/legacy/messaging/more_3.png',
          title: 'KING CLUB 金币',
          subtitle: '${message.text} · 赠送成功',
        );
      case _FakeMessageKind.redPacket:
        return _LegacyValueMessageCard(
          key: const ValueKey('direct-chat-red-packet-message'),
          assetPath: 'assets/legacy/messaging/more_4.png',
          title: 'KING CLUB 红包',
          subtitle: message.text,
        );
      case _FakeMessageKind.gift:
        return Container(
          key: const ValueKey('direct-chat-gift-message'),
          width: 210,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF231F1B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x554A4037)),
          ),
          child: Row(
            children: [
              Image.asset(
                message.assetPath!,
                width: 58,
                height: 58,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '赠送礼物',
                      style: TextStyle(color: Color(0xFF8A8178), fontSize: 11),
                    ),
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: legacyMessageGold,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _LegacyValueMessageCard extends StatelessWidget {
  const _LegacyValueMessageCard({
    super.key,
    required this.assetPath,
    required this.title,
    required this.subtitle,
  });

  final String assetPath;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 228,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF8B6E48),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(assetPath, width: 42, height: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0x44FFFFFF)),
          const SizedBox(height: 5),
          const Text(
            'KING CLUB',
            style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  const _AttachmentAction({
    this.icon,
    this.assetPath,
    required this.label,
    required this.onTap,
  }) : assert(icon != null || assetPath != null);

  final IconData? icon;
  final String? assetPath;
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
              child: assetPath != null
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        assetPath!,
                        color: legacyMessageGold,
                        colorBlendMode: BlendMode.srcIn,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Icon(icon, color: legacyMessageGold),
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
