import 'package:flutter/material.dart';

import 'legacy_messaging_components.dart';

class ContactSelectorPage extends StatefulWidget {
  const ContactSelectorPage({super.key, this.preview = '“周末 KING CLUB 见”'});

  final String preview;

  @override
  State<ContactSelectorPage> createState() => _ContactSelectorPageState();
}

class _ContactSelectorPageState extends State<ContactSelectorPage> {
  final _searchController = TextEditingController();
  bool _alphabetical = false;
  String? _selected;

  static const _contacts = ['卡座搭子', '艾琳', '阿浩', '墨墨'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final contacts = _contacts
        .where((name) => name.toLowerCase().contains(query))
        .toList();
    if (_alphabetical) contacts.sort();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            LegacyMessagingHeader(
              title: '选择联系人',
              onBack: () => Navigator.pop(context, false),
              trailing: TextButton(
                key: const ValueKey('contact-selector-sort'),
                onPressed: () => setState(() => _alphabetical = !_alphabetical),
                child: Text(
                  _alphabetical ? '按首字母' : '按最近聊天',
                  style: const TextStyle(
                    color: legacyMessageGold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 14, 30, 10),
              child: TextField(
                key: const ValueKey('contact-selector-search'),
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '搜索',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  filled: true,
                  fillColor: const Color(0x22C9B69E),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: contacts.isEmpty
                  ? const Center(
                      child: Text(
                        '没有找到可转发的好友',
                        style: TextStyle(color: Color(0x66FFFFFF)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: contacts.length,
                      itemBuilder: (context, index) {
                        final name = contacts[index];
                        return Material(
                          color: const Color(0x0EC9B69E),
                          child: InkWell(
                            key: ValueKey('contact-selector-$name'),
                            onTap: () => setState(() => _selected = name),
                            child: SizedBox(
                              height: 66,
                              child: Row(
                                children: [
                                  const SizedBox(width: 30),
                                  Icon(
                                    _selected == name
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                    color: legacyMessageGold,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 6),
                                  const LegacyFakeAvatar(size: 45),
                                  const SizedBox(width: 14),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(24, 10, 24, 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const ValueKey('contact-selector-submit'),
                  onPressed: _selected == null ? null : _confirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(112, 44),
                    backgroundColor: const Color(0xFF1AAD19),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_selected == null ? '转发(0)' : '转发(1)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: legacyMessagePanel,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '发送给 $_selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                color: const Color(0x22C9B69E),
                child: Text(
                  widget.preview,
                  style: const TextStyle(color: Color(0xCCFFFFFF)),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('contact-selector-confirm'),
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('发送'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext, false),
                child: const Text('取消'),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context, true);
  }
}
