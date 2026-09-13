import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/chat_location.dart';
import '../data/chat_location_lookup.dart';

/// Selecting a candidate never sends it; the explicit confirm returns it.
class ChatLocationPickerPage extends StatefulWidget {
  const ChatLocationPickerPage({super.key, this.lookup, this.onConfirm});
  final ChatLocationLookup? lookup;
  final Future<void> Function(ChatLocation)? onConfirm;
  @override
  State<ChatLocationPickerPage> createState() => _ChatLocationPickerPageState();
}

class _ChatLocationPickerPageState extends State<ChatLocationPickerPage> {
  late final ChatLocationLookup _lookup =
      widget.lookup ?? NativeChatLocationLookup();
  final _query = TextEditingController();
  StreamSubscription<void>? _session;
  List<ChatLocation> _results = [];
  ChatLocation? _selected;
  String? _error;
  bool _busy = false, _invalid = false, _sending = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (!mounted) return;
      _generation++;
      setState(() {
        _invalid = true;
        _busy = false;
        _results = [];
        _selected = null;
        _error = '登录状态已变化，请重新进入';
      });
    });
  }

  Future<void> _load(bool current) async {
    if (_invalid || _sending) return;
    final generation = ++_generation;
    setState(() {
      _busy = true;
      _error = null;
      _selected = null;
      _results = [];
    });
    try {
      final results = current
          ? [await _lookup.current()]
          : await _lookup.search(_query.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        if (results.isEmpty) _error = '没有找到地点，请输入更完整的地址';
      });
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : '无法获取地点，请重试',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null || _invalid || _busy || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onConfirm?.call(selected);
      if (mounted && !_invalid) Navigator.of(context).pop(selected);
    } catch (_) {
      if (mounted && !_invalid) setState(() => _error = '发送未完成，请重试');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('发送位置'),
      leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
    ),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _query,
              enabled: !_invalid && !_sending,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(false),
              decoration: InputDecoration(
                hintText: '搜索地点或详细地址',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: '搜索地点',
                  onPressed: _invalid || _sending ? null : () => _load(false),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.my_location),
            title: const Text('使用当前位置'),
            onTap: _busy || _invalid || _sending ? null : () => _load(true),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final location = _results[index],
                    selected = _selected == location;
                return ListTile(
                  onTap: _sending
                      ? null
                      : () => setState(() => _selected = location),
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(location.name),
                  subtitle: Text(
                    location.address.isNotEmpty
                        ? location.address
                        : '${(location.latitudeE6 / 1000000).toStringAsFixed(6)}, ${(location.longitudeE6 / 1000000).toStringAsFixed(6)}',
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null || _invalid || _busy || _sending
                    ? null
                    : _confirm,
                child: Text(_sending ? '正在发送…' : '确认发送此位置'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
