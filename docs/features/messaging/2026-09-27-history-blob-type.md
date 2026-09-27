# 历史删除保护密文的 SQLite 类型修正

## 问题

运行历史回归测试时出现 sqflite 不支持 `CastList<int,int>` 的参数警告。本机依赖 `sqflite_common 2.5.12` 的参数校验代码明确说明未来会把该警告升级为异常。

`ChatHistoryStore.commit` 为防止旧分页把已隐藏/撤回消息恢复，会在事务内读取已保存密文，并在必要时复用原密文写回。此前读取后调用 `List.cast<int>()`，保留了字节内容，但丢失 SQLite BLOB 写入所需的 `Uint8List` 类型。

## 修正

保存待复用密文的映射改为 `Uint8List`；数据库已返回 `Uint8List` 时直接复用，否则复制为 `Uint8List`。保持原字节、AAD、AES-GCM、事务、epoch/historyVersion、撤回与本地删除优先规则不变。不需要数据库迁移，不触及用户密钥或清除记录。

测试使用当前驱动的严格参数开关，将不支持的参数视为异常，并在每项测试后恢复开关。仅测试依赖直接声明已锁定的 `sqflite_common 2.5.12`；离线依赖解析后 lock 仅从 transitive 变为 direct dev，没有升级依赖版本。

## 证据

- 改生产代码前，启用严格检查后，`old tombstones outside loaded pages survive stale server pagination` 确认失败，错误为不支持的二进制参数类型。
- 修正后 `direct_chat_history_test.dart`、`chat_deferred_media_cleanup_test.dart`、`chat_media_reference_guard_test.dart` 共 23 项通过，包含离线重开、旧分页、清空期间迟到写入、共享媒体引用保护。
- 两个修改 Dart 文件 analyze 通过。

这是 SQLite 参数兼容性和持久化可靠性修正，不证明会话动画卡顿已解决。当前只完成代码和自动化验证，尚未打入 A/B 已安装的 `AA1A4AAC...` 包。
