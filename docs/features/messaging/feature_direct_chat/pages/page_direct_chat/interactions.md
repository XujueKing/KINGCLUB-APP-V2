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

## UI Mock 细化（2026-08-27）

- 输入为空时发送按钮为禁用态；输入文字后启用，发送时先显示本地“发送中”，随后进入已发送或可重试失败态。
- “图片”插入本地合成图片缩略图；“短视频”插入带播放标识的本地静态封面；点击均进入全屏 Fake 预览。
- “业务卡片”显示可识别的凭证卡片，而不是普通文本占位。
- 复制仅对文字消息出现；引用对所有支持的消息生成摘要，并在输入栏上方显示可关闭的引用草稿条。
- 为我删除和撤回均先显示确认对话框；撤回后原位置变为居中系统文字。
