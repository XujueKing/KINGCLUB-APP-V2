import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../messaging/data/messaging_repository.dart';

class ContactGroup {
  ContactGroup(this.id, this.name, this.icon, Set<String> members)
    : members = Set.unmodifiable(members);
  final String id, name;
  final int icon;
  final Set<String> members;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'icon': icon,
    'members': members.toList()..sort(),
  };
  factory ContactGroup.fromJson(Map<String, dynamic> value) {
    final icon = value['icon'] as int;
    if (icon < 0 || icon > 7) throw const FormatException('关系图标无效');
    return ContactGroup(
      value['id'] as String,
      value['name'] as String,
      icon,
      (value['members'] as List).cast<String>().toSet(),
    );
  }
}

class ContactGroupsRepository {
  ContactGroupsRepository(this.messaging);
  final MessagingRepository messaging;
  int? _version;
  int _operation = 0;
  bool _saving = false;
  String? _pendingPayload, _pendingId;
  Future<List<ContactGroup>> load() async {
    if (_saving) throw StateError('正在保存关系分组');
    final operation = ++_operation;
    final response = await messaging.call('K260913000615', {});
    if (operation != _operation) throw StateError('分组读取已被更新操作替代');
    final groups = _parse(response);
    _version = response['version'] as int;
    _pendingPayload = null;
    _pendingId = null;
    return groups;
  }

  Future<List<ContactGroup>> save(List<ContactGroup> groups) async {
    if (_version == null) throw StateError('请先读取关系分组');
    if (_saving) throw StateError('正在保存关系分组');
    _operation++;
    _saving = true;
    try {
      final payload = groups.map((group) => group.toJson()).toList();
      final identity = jsonEncode({'version': _version, 'groups': payload});
      if (identity != _pendingPayload) {
        _pendingPayload = identity;
        _pendingId = const Uuid().v4();
      }
      final response = await messaging.call('K260913000616', {
        'version': _version,
        'requestId': _pendingId,
        'groups': payload,
      });
      final saved = _parse(response);
      _version = response['version'] as int;
      _pendingPayload = null;
      _pendingId = null;
      return saved;
    } finally {
      _saving = false;
    }
  }

  List<ContactGroup> _parse(Map<String, dynamic> response) =>
      (response['groups'] as List)
          .map(
            (value) =>
                ContactGroup.fromJson(Map<String, dynamic>.from(value as Map)),
          )
          .toList();
}
