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
  const CreateGroupPage({super.key, this.repository, this.chatOutbox});
  final GroupChatRepository? repository;
  final ChatOutbox? chatOutbox;
  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _name = TextEditingController();
  final _selected = <String>{};
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Column(
        children: [
          LegacyMessagingHeader(
            title: '发起群聊',
            onBack: () => Navigator.maybePop(context),
            trailing: TextButton(
              onPressed: _invalid || _saving || _selected.isEmpty
                  ? null
                  : _create,
              child: Text('创建（${_selected.length}）'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: TextField(
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
              itemCount: _contacts?.contacts.length ?? 0,
              separatorBuilder: (_, _) => const Divider(
                indent: 72,
                endIndent: 24,
                height: 1,
                color: Color(0xFF1A1611),
              ),
              itemBuilder: (context, index) {
                final contact = _contacts!.contacts[index];
                return CheckboxListTile(
                  value: _selected.contains(contact.account),
                  onChanged: _invalid || _saving
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
          if (_contacts?.hasSnapshot == true && _contacts!.contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('暂无可选择的好友', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    ),
  );
}
