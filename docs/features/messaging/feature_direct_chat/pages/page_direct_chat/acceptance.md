# 单聊页验收

- [x] 页面结构、消息类型、输入、媒体、引用、转发和返回明确
- [x] outbox、clientMessageId、状态机、重试、分页与实时合并明确
- [x] 消息菜单、关系结束、已读、隐私和无障碍明确
- [x] 用户批准按旧版页面进行 UI/Fake 复刻

## UI Mock 实现验收（2026-08-27）

- [x] 旧版黑色顶栏、左右头像气泡和深色输入面板已实现
- [x] Fake 文本发送、失败重试、附件、引用、转发、删除和撤回可演示
- [x] 红包、金币、礼物、群聊和真实 WebSocket/媒体能力保持阻断
- [x] Android 1080×2400 无溢出或输入区遮挡
- [x] 消息流改为微信式从上向下排列，少量消息不再挤在页面底部
- [x] 首次好友单聊先显示“已添加好友，现在可以开始聊天”系统提醒
- [x] 图片/短视频/业务卡片使用真实可识别的 Mock 视觉，不再显示文字占位
- [x] 输入启用态、引用草稿条、复制反馈和发送状态可演示
- [x] 删除与撤回二次确认、媒体全屏预览可演示
- [ ] 等待旧版运行截图后完成最终 1:1 视觉验收

最新实现证据：[普通单聊](android_direct_chat_wechat_flow.png)、[接受好友后进入单聊](android_friend_accepted_chat.png)、[附件面板](android_chat_attachment_panel.png)、[图片消息](android_chat_image_message.png)、[媒体预览](android_chat_media_preview.png)、[消息操作](android_chat_message_actions.png)、[引用草稿](android_chat_quote_draft.png)。

未来 UI Mock 验证 CHAT-M01～M13、M18；批准前不得实现页面。
