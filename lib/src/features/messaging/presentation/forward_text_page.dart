import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/secure_session_store.dart';
import '../../contacts/data/contacts_controller.dart';
import '../data/chat_outbox.dart';
import '../data/chat_location.dart';
import '../data/chat_image_forwarder.dart';
import '../data/chat_file_forwarder.dart';
import '../data/chat_file_downloader.dart';
import '../data/chat_file_uploader.dart';
import '../data/messaging_repository.dart';
import 'chat_member_avatar.dart';
import 'direct_chat_page.dart';
import 'legacy_messaging_components.dart';

class _ForwardTarget {
  const _ForwardTarget(this.account, this.displayName, {this.group = false});
  final String account, displayName;
  final bool group;
}

class ForwardTextPage extends StatefulWidget {
  const ForwardTextPage({
    super.key,
    required this.repository,
    required this.text,
    this.outbox,
    this.location,
    this.imageMessageId,
    this.sourceGroup = false,
    this.createImageForwarder,
    this.file,
    this.createFileForwarder,
  });
  final MessagingRepository repository;
  final String text;
  final ChatLocation? location;
  final String? imageMessageId;
  final bool sourceGroup;
  final ChatFileReference? file;
  final ChatFileForwarder Function()? createFileForwarder;
  final ChatImageForwarder Function()? createImageForwarder;
  final ChatOutbox? outbox;
  @override
  State<ForwardTextPage> createState() => _ForwardTextPageState();
}

class _ForwardTextPageState extends State<ForwardTextPage> {
  late final _contacts = ContactsController(widget.repository);
  late final _outbox =
      widget.outbox ?? SecureChatOutbox(widget.repository.account);
  final _search = TextEditingController();
  final _profiles = <String, Future<Map<String, dynamic>>>{};
  StreamSubscription<void>? _session;
  _ForwardTarget? _selected;
  final _groups = <_ForwardTarget>[];
  bool _showGroups = false, _loadingGroups = false, _groupsLoaded = false;
  String? _groupCursor, _groupError;
  BuildContext? _confirmationContext;
  ChatImageForwarder? _imageForwarder;
  ChatFileForwarder? _fileForwarder;
  Map<String, dynamic>? _attempt;
  bool _saving = false, _invalid = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _contacts.addListener(_changed);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      final dialog = _confirmationContext;
      if (dialog != null && dialog.mounted) Navigator.of(dialog).pop(false);
      _contacts.invalidate();
      _profiles.clear();
      _groups.clear();
      _selected = null;
      _search.clear();
      _error = '登录状态已变化，请重新进入';
      _changed();
    });
    unawaited(_contacts.refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _session?.cancel();
    _contacts.removeListener(_changed);
    _contacts.dispose();
    _search.dispose();
    _imageForwarder?.dispose();
    _fileForwarder?.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    if (_invalid || _loadingGroups) return;
    setState(() {
      _loadingGroups = true;
      _groupError = null;
    });
    try {
      final page = await widget.repository.call('K260913000618', {
        'limit': 100,
        if (_groupCursor != null) 'before': _groupCursor,
      });
      if (!mounted || _invalid) return;
      final rows = page['items'];
      if (rows is! List) throw const FormatException('Invalid group list');
      final next = page['nextCursor'];
      if (next != null && (next is! String || next == _groupCursor)) {
        throw const FormatException('Invalid group cursor');
      }
      final incoming = rows.map((raw) {
        final row = Map<String, dynamic>.from(raw as Map);
        return _ForwardTarget(
          row['groupId'] as String,
          row['groupName'] as String,
          group: true,
        );
      }).toList();
      final known = _groups.map((g) => g.account).toSet();
      _groups.addAll(incoming.where((g) => known.add(g.account)));
      _groupCursor = next as String?;
      _groupsLoaded = true;
    } catch (_) {
      if (mounted && !_invalid) _groupError = '群聊读取失败，点击重试';
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  Future<void> _forward() async {
    final target = _selected;
    if (_saving || _invalid || target == null) return;
    setState(() => _saving = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          _confirmationContext = context;
          return AlertDialog(
            title: Text('发送给 ${target.displayName}'),
            content: SingleChildScrollView(
              child: Text(
                widget.file != null
                    ? widget.file!.fileName
                    : widget.imageMessageId != null
                    ? '[图片]'
                    : widget.location == null
                    ? widget.text
                    : '${widget.location!.name}\n${widget.location!.address}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                key: const ValueKey('forward-text-confirm'),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('发送'),
              ),
            ],
          );
        },
      );
      _confirmationContext = null;
      if (confirmed != true || !mounted || _invalid) return;
      if (widget.file == null &&
          widget.imageMessageId == null &&
          widget.location == null &&
          (widget.text.trim().isEmpty || widget.text.length > 4000)) {
        throw StateError('文字长度无效');
      }
      int? membershipVersion;
      if (target.group && _attempt == null) {
        final details = await widget.repository.call('K260913000619', {
          'groupId': target.account,
        });
        if (!mounted || _invalid) return;
        if (details['groupId'] != target.account ||
            details['membershipVersion'] is! int) {
          throw StateError('群成员状态尚未确认');
        }
        membershipVersion = details['membershipVersion'] as int;
      }
      String? imageAssetId;
      if (widget.imageMessageId != null && _attempt == null) {
        final forwarder = _imageForwarder ??=
            widget.createImageForwarder?.call() ??
            ChatImageForwarder(
              repository: widget.repository,
              messageId: widget.imageMessageId!,
              group: widget.sourceGroup,
            );
        imageAssetId = (await forwarder.prepare()).assetId;
        if (!mounted || _invalid) return;
      }
      UploadedChatFile? uploadedFile;
      if (widget.file != null && _attempt == null) {
        final forwarder = _fileForwarder ??=
            widget.createFileForwarder?.call() ??
            ChatFileForwarder(
              repository: widget.repository,
              reference: widget.file!,
            );
        uploadedFile = await forwarder.prepare();
        if (!mounted || _invalid) return;
      }
      _attempt ??= {
        'clientMessageId': const Uuid().v4(),
        if (target.group) ...{
          'groupId': target.account,
          'membershipVersion': membershipVersion,
        } else
          'recipient': target.account,
        'sender': widget.repository.account,
        'text': widget.file != null
            ? '[文件]'
            : widget.imageMessageId != null
            ? '[图片]'
            : widget.location == null
            ? widget.text.trim()
            : '[位置]',
        if (imageAssetId != null) ...{
          'messageType': 'image',
          'imageAssetId': imageAssetId,
        },
        if (widget.location != null) ...{
          'messageType': 'location',
          'location': widget.location!.toJson(),
        },
        if (uploadedFile != null) ...{
          'messageType': 'file',
          'fileAssetId': uploadedFile.assetId,
          'fileName': uploadedFile.fileName,
          'fileSize': uploadedFile.size,
          'fileSha256': uploadedFile.sha256,
        },
        'createdDate': DateTime.now().toUtc().toIso8601String(),
        'status': 'queued',
      };
      await _outbox.put(_attempt!);
      try {
        await _imageForwarder?.acknowledgeQueued();
        await _fileForwarder?.acknowledgeQueued();
      } catch (_) {}
      if (!mounted || _invalid) return;
      // The target conversation restores this exact queued ID and owns retries.
      unawaited(
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(
            builder: (_) => DirectChatPage(
              peerName: target.displayName,
              peerAccount: target.group ? null : target.account,
              groupId: target.group ? target.account : null,
              repository: widget.repository,
              chatOutbox: _outbox,
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted && !_invalid) setState(() => _error = '转发未完成，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _invalid
        ? <_ForwardTarget>[]
        : _showGroups
        ? _groups
              .where(
                (g) => g.displayName.toLowerCase().contains(
                  _search.text.trim().toLowerCase(),
                ),
              )
              .toList()
        : _contacts
              .search(_search.text)
              .map((c) => _ForwardTarget(c.account, c.displayName))
              .toList();
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              LegacyMessagingHeader(
                title: '选择联系人',
                onBack: _saving ? () {} : () => Navigator.pop(context),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final group in [false, true])
                    TextButton(
                      onPressed: _invalid || _saving
                          ? null
                          : () {
                              setState(() {
                                _showGroups = group;
                                _selected = null;
                                _attempt = null;
                              });
                              if (group && !_groupsLoaded) {
                                unawaited(_loadGroups());
                              }
                            },
                      child: Text(
                        group ? '群聊' : '好友',
                        style: TextStyle(
                          color: _showGroups == group
                              ? Colors.white
                              : legacyMessageGold,
                        ),
                      ),
                    ),
                ],
              ),
              if (_showGroups && (_groupError != null || _groupCursor != null))
                TextButton(
                  onPressed: _loadingGroups ? null : _loadGroups,
                  child: Text(_groupError ?? '加载更多群聊'),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _search,
                  enabled: !_invalid && !_saving,
                  onChanged: (_) => _changed(),
                  decoration: const InputDecoration(
                    hintText: '搜索',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              if (_error != null || _contacts.error != null)
                TextButton(
                  onPressed: _invalid || _saving
                      ? null
                      : () => _contacts.refresh(),
                  child: Text(_error ?? '通讯录读取失败，点击重试'),
                ),
              Expanded(
                child: contacts.isEmpty
                    ? Center(
                        child: Text(
                          (_showGroups ? _groupsLoaded : _contacts.hasSnapshot)
                              ? '没有找到可转发的对象'
                              : '',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: contacts.length,
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return ListTile(
                            key: ValueKey('forward-text-${contact.account}'),
                            leading: contact.group
                                ? const Icon(
                                    Icons.group,
                                    color: legacyMessageGold,
                                    size: 36,
                                  )
                                : ChatMemberAvatar(
                                    account: contact.account,
                                    profile: _profiles.putIfAbsent(
                                      contact.account,
                                      () => widget.repository.call(
                                        'K260913000612',
                                        {'peer': contact.account},
                                      ),
                                    ),
                                  ),
                            title: Text(
                              contact.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                            trailing: Icon(
                              _selected?.account == contact.account
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: legacyMessageGold,
                            ),
                            onTap: _saving
                                ? null
                                : () => setState(() {
                                    if (_selected?.account != contact.account) {
                                      _attempt = null;
                                    }
                                    _selected = contact;
                                  }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: FilledButton(
                  key: const ValueKey('forward-text-submit'),
                  onPressed: _saving || _invalid || _selected == null
                      ? null
                      : _forward,
                  child: const Text('转发'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
