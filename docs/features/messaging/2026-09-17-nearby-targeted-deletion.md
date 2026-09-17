# 单条删除同步清理附近直连日志

删除已与服务端对账的单聊消息时，原实现清理普通历史，但附近直连日志副本要等下一次服务端隐藏标记同步才清理。本次在历史删除事务内，按会员会话和服务端消息 ID 将对应直连副本隐藏并清空加密正文，保留防重复投递标记。其他会话不受影响；未发送队列策略不变。

验证：`nearby_targeted_deletion_test.dart` 使用真实临时 SQLite，覆盖两设备副本正文清空、重开数据库、旧设备及新设备重复投递不复活、另一会话正文保留。与 nearby_member_history、nearby_history_reconciliation、chat_history_deletion_events 合计 10 项通过；修改文件静态分析通过。

本节点尚未打包安装到手机，不计为真机验收完成。
