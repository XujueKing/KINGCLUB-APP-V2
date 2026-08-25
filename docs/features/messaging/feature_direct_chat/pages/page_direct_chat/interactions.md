# 单聊页交互

| 触发 | 行为 |
|---|---|
| 发送文本 | 校验 1～2000 字，生成 clientMessageId 后进入 outbox |
| 失败重试 | 复用同一 clientMessageId/幂等键，不插入新气泡 |
| 选择媒体 | Fake picker → intent/upload/commit → send |
| 上拉更早历史 | beforeCursor SingleFlight 加载并保持视口锚点 |
| 长按消息 | 按类型/权限显示复制、引用、转发、为我删除、撤回 |
| 转发 | `openContactSelector(ShareIntentRef)` |
| 标题/头像 | `openUserProfile(peerRef)` |
| 详情 | `openDirectChatDetails(conversationRef)` |

- 输入草稿只存当前会话、当前 generation；切换账号清除。
- 页面可离线排队纯文本，但媒体离线只保留本次页面内草稿，不后台上传。
- 真正呈现消息后才推进 read cursor；WebSocket 事件先去重再合并/补拉。
- 撤回窗口由服务端返回 allowedActions 决定，客户端不硬编码旧版两分钟。
