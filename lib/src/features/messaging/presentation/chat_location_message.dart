import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_notice.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/chat_location.dart';

class ChatLocationMessage extends StatelessWidget {
  const ChatLocationMessage({
    super.key,
    required this.location,
    required this.mine,
    required this.onTap,
  });
  final ChatLocation location;
  final bool mine;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = mine ? const Color(0xFF193E2B) : const Color(0xFFC9B69E);
    return Semantics(
      button: true,
      label: '查看位置：${location.name}',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 210,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.location_on, size: 22, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      location.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontSize: 15),
                    ),
                  ),
                ],
              ),
              if (location.address.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  location.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                '位置',
                style: TextStyle(
                  color: color.withValues(alpha: 0.65),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatLocationDetailsPage extends StatefulWidget {
  const ChatLocationDetailsPage({super.key, required this.location});
  final ChatLocation location;
  @override
  State<ChatLocationDetailsPage> createState() =>
      _ChatLocationDetailsPageState();
}

class _ChatLocationDetailsPageState extends State<ChatLocationDetailsPage> {
  StreamSubscription<void>? _session;
  bool _valid = true;
  @override
  void initState() {
    super.initState();
    _session = SecureSessionStore.changes.stream.listen((_) {
      if (mounted) setState(() => _valid = false);
    });
  }

  @override
  void dispose() {
    _session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.location;
    final coordinates =
        '${(location.latitudeE6 / 1e6).toStringAsFixed(6)}, '
        '${(location.longitudeE6 / 1e6).toStringAsFixed(6)}';
    final system = location.coordinateSystem == 'gcj02' ? 'GCJ-02' : 'WGS84';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('位置'),
        backgroundColor: Colors.black,
        leading: KingBackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: !_valid
              ? const Text('登录状态已变化，请重新进入')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: const TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    if (location.address.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        location.address,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      '经纬度：$coordinates',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '坐标系：$system',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      label: const Text('复制地点信息'),
                      onPressed: () async {
                        if (!_valid) return;
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${location.name}\n${location.address}\n$coordinates ($system)',
                          ),
                        );
                        if (context.mounted && _valid) {
                          KingNotice.of(context).show('地点信息已复制');
                        }
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
