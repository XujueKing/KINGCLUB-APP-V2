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
  });
  final GroupChatRepository? repository;
  final ChatOutbox? chatOutbox;
  final String? inviteGroupId;
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
  StreamSubscription<void>? _session;
  bool _invalid = false, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      _invalid = true;
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
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: widget.inviteGroupId == null ? '发起群聊' : '邀请好友',
              onBack: () => Navigator.maybePop(context),
              trailing: TextButton(
                onPressed: _invalid || _saving || _selected.isEmpty
                    ? null
                    : _create,
                child: Text(
                  '${widget.inviteGroupId == null ? '创建' : '邀请'}（${_selected.length}）',
                ),
              ),
            ),
            if (widget.inviteGroupId == null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: TextField(
                  key: const ValueKey('create-group-name'),
                  controller: _name,
                  enabled: !_invalid && !_saving,
                  maxLength: 64,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: '群名称',
                    counterText: '',
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: TextField(
                key: const ValueKey('group-contact-search'),
                controller: _search,
                enabled: !_invalid && !_saving,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(color: Color(0xFFC9B69E), fontSize: 15),
                decoration: InputDecoration(
                  hintText: '搜索备注、昵称或会员号',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey,
                  ),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清除搜索',
                          onPressed: _invalid || _saving
                              ? null
                              : () => setState(_search.clear),
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                  filled: true,
                  fillColor: const Color(0x0DFFFFFF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(7),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
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
                  indent: 72,
                  endIndent: 24,
                  height: 1,
                  color: Color(0xFF1A1611),
                ),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  return CheckboxListTile(
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
                    secondary: const Icon(
                      Icons.person_outline,
                      color: Color(0xFFC9B69E),
                    ),
                    title: Text(
                      contact.displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                },
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
