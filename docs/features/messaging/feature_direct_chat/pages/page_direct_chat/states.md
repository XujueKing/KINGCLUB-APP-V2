# 单聊页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 顶栏 + 历史骨架，输入禁用 |
| `ready` | 历史、输入、媒体与详情 |
| `empty` | 安全开场提示 + 输入 |
| `loadingEarlier` | 保留历史 + 顶部进度 |
| `offlineCached` | 缓存历史，可排队文本但明确离线 |
| `sending` | 单条 queued/uploading/sending 状态 |
| `messageFailed` | 单条失败 + 重试/删除本地草稿 |
| `readOnlyRelationshipEnded` | 历史可见，输入禁用 |
| `partialError` | 保留历史 + 局部重试 |
| `fatalError` | 重试/返回 |
| `sessionInvalid` | 清空草稿/媒体/历史并 reset |

messageId/clientMessageId 去重；消息版本和 serverSequence 不倒退；旧 generation 不得恢复正文。
