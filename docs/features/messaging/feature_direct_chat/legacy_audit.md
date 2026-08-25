# 单聊旧版审计

- 文档状态：`Approved for Development`

| 旧实现 | 风险 | V2 取舍 |
|---|---|---|
| 本地 timestamp messageId | 与服务端 ID 替换存在竞态 | clientMessageId 与 messageId 分离 |
| HTTP + push + socket 三次动作 | 发送成功/投递含义混乱 | API 持久化权威，事件仅提示 |
| `S231202503110661` | lastMessageId/stamp 与本地库混合合并 | 不透明历史 cursor + 版本去重 |
| 上传 URL | 含账号、会话 ID和共享凭据 | media intent/upload/commit |
| 本地删除/撤回 | 只改本机且伪造结果 | 命名 deleteForMe/revoke 命令 |
| chat_more | 单聊设置和群管理混合 | KC-P-025 只保留单聊设置 |
| select-chat | URI 信任订单、账号等完整参数 | ShareIntentRef 内存上下文 |

旧 messageType 数字和接口 ID不得直接成为 V2 契约。
