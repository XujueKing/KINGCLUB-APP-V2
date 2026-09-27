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

## 扩大回归与后续安装

群聊历史、历史仓库、附近消息、会员关联及附近消息对账 5 个测试文件首次执行为 92 通过、1 失败。失败的 v6 升级夹具仅创建 message/nearby_message，遗漏实际 v6 已有的 conversation 表，导致新版本 ALTER TABLE 找不到表。对照历史提交 `b486dd04` 补全该表原结构，没有放宽生产升级逻辑。再次执行全部 5 个文件，93 项通过；夹具文件 analyze 通过。

包含密文 BLOB 修正的 profile 包 SHA256 为 `2AF670157D37284EDB3527D08EB9E3CC0B4D8C85F2396714E23B650009981889`，构建脚本的正式包名与原生库检查通过。A/B 均覆盖安装 Success 并启动，没有卸载或清数据；隔离构建仅同步本次 history store 改动，不混入其他栏目。

### B 离线冷启动检查

先确认 B Wi-Fi 开启、mobile_data=0。临时关闭 Wi-Fi，force-stop 正式包后重开（不清数据），进入消息页：已有会话仍显示，进入 A/B 会话可见 `AB_UI_SMOOTH_0927_02` 一次。随后恢复 Wi-Fi。

再以相同网络前提关闭 Wi-Fi并冷启动，进入通讯录可见新的朋友入口及原 A 联系人；采集时 wifi_on=0。finally 恢复 Wi-Fi，读回 wifi_on=1。未操作第三台手机，也没有发送离线测试消息或改动好友关系。

这证明本次真实设备的离线会话列表、历史和通讯录读取成功；不等同于首帧无闪烁或所有媒体已离线验收。原始 UI 转储保留于隔离构建目录 `build/chat-offline-list.xml`、`chat-offline-history.xml`、`chat-offline-contacts.xml`，不入库。
