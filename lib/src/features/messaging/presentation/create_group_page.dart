import 'chat_member_avatar.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../../contacts/data/contacts_controller.dart';
import '../data/group_chat_repository.dart';
import '../data/messaging_repository.dart';
import '../data/chat_outbox.dart';
import 'direct_chat_page.dart';
import 'legacy_messaging_components.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({
    super.key,
    this.repository,
    this.chatOutbox,
    this.inviteGroupId,
    this.initialMembers = const {},
  });
  final GroupChatRepository? repository;
  final ChatOutbox? chatOutbox;
  final String? inviteGroupId;
  final Set<String> initialMembers;
  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _selected = <String>{};
  final _existing = <String>{};
  ContactsController? _contacts;
  GroupChatRepository? _repository;
  final _avatarProfiles = <String, Future<Map<String, dynamic>>>{};
  StreamSubscription<void>? _session;
  bool _invalid = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
      _avatarProfiles.clear();
      _contacts?.invalidate();
      if (mounted) {
        setState(() {
          _selected.clear();
          _name.clear();
          _search.clear();
          _error = '登录状态已变化，请重新进入';
        });
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_invalid) return;
    try {
      final repository =
          _repository ??
          widget.repository ??
          GroupChatRepository(await MessagingRepository.open());
      if (!mounted || _invalid) return;
      _repository = repository;
      _contacts ??= ContactsController(repository.messaging)
        ..addListener(_changed);
      await _contacts!.refresh();
      if (!mounted || _invalid) return;
      if (widget.inviteGroupId == null) {
        _selected.addAll(
          widget.initialMembers.where(
            (account) => _contacts!.contacts.any((c) => c.account == account),
          ),
        );
      }
      if (widget.inviteGroupId != null) {
        final details = await repository.details(widget.inviteGroupId!);
        if (!mounted || _invalid) return;
        _existing.clear();
        _existing.addAll(
          (details['members'] as List).map(
            (m) => (m as Map)['account'] as String,
          ),
        );
      }
      if (mounted && !_invalid) {
        setState(() {
          _error = _contacts!.error;
        });
      }
    } catch (error) {
      if (mounted && !_invalid) {
        setState(() {
          _error = error.toString();
        });
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _create() async {
    if (_saving || _invalid || _repository == null) return;
    if (widget.inviteGroupId == null && _name.text.trim().isEmpty) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('设置群名称'),
          content: TextField(
            key: const ValueKey('create-group-name'),
            controller: _name,
            autofocus: true,
            maxLength: 64,
            decoration: const InputDecoration(hintText: '群名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (_name.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('创建'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted || _invalid) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.inviteGroupId != null) {
        // Individual acknowledgements retain failed selections for safe retries.
        for (final target in _selected.toList()) {
          final invitation = await _repository!.invite(
            widget.inviteGroupId!,
            target,
          );
          if (!mounted || _invalid) return;
          if (invitation['status'] != 'pending') {
            throw StateError(
              '邀请已${invitation['status'] == 'expired' ? '过期' : '处理'}，请重新发送',
            );
          }
          setState(() {
            _selected.remove(target);
            _existing.add(target);
          });
        }
        if (mounted && !_invalid) Navigator.pop(context, true);
        return;
      }
      final result = await _repository!.create(
        name: _name.text,
        members: _selected,
      );
      if (!mounted || _invalid) return;
      final groupName = _name.text.trim();
      final messaging = _repository!.messaging;
      final outbox = widget.chatOutbox;
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => DirectChatPage(
            groupId: result['groupId'] as String,
            peerName: groupName,
            repository: messaging,
            chatOutbox: outbox,
          ),
        ),
      );
    } catch (error) {
      if (mounted && !_invalid) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _session?.cancel();
    _contacts?.removeListener(_changed);
    _contacts?.dispose();
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _contacts?.search(_search.text) ?? const <MemberContact>[];
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: '选择联系人',
              backgroundColor: const Color(0xFF111111),
              lineColor: Colors.transparent,
              onBack: () => Navigator.maybePop(context),
            ),
            LegacyConversationSearch(
              inputKey: const ValueKey('group-contact-search'),
              controller: _search,
              enabled: !_invalid && !_saving,
              maxLength: 100,
              onChanged: (_) => setState(() {}),
              onClear: () {
                if (!_invalid && !_saving) setState(_search.clear);
              },
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextButton(
                  onPressed: _invalid || _saving ? null : _load,
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: contacts.length,
                separatorBuilder: (_, _) => const Divider(
                  indent: 0,
                  endIndent: 0,
                  height: 1,
                  color: Color(0xFF292929),
                ),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    checkboxShape: const CircleBorder(),
                    activeColor: const Color(0xFF07C160),
                    checkColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF666666), width: 1),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    tileColor: const Color(0xFF191919),
                    value: _selected.contains(contact.account),
                    onChanged:
                        _invalid ||
                            _saving ||
                            _existing.contains(contact.account)
                        ? null
                        : (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(contact.account);
                              } else {
                                _selected.remove(contact.account);
                              }
                            });
                          },
                    title: Row(
                      children: [
                        ChatMemberAvatar(
                          account: contact.account,
                          profile: _avatarProfiles.putIfAbsent(
                            contact.account,
                            () => _repository!.messaging.avatarProfile(
                              contact.account,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            contact.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              color: const Color(0xFF191919),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    key: const ValueKey('create-group-complete'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF07C160),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: _invalid || _saving || _selected.isEmpty
                        ? null
                        : _create,
                    child: Text(_saving ? '正在提交…' : '完成（${_selected.length}）'),
                  ),
                ],
              ),
            ),
            if (_contacts?.hasSnapshot == true && contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _search.text.trim().isEmpty ? '暂无可选择的好友' : '未找到匹配的好友',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
