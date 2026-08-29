# J04 消息链 UI Mock 验收记录

- 日期：2026-08-29
- 构建：`preview / 1.0.0-preview (1)`
- 入口：`KINGCLUB_INITIAL_LOCATION=/home`
- 设备：Android USB 真机，物理 `1440 × 3200 @ 560dpi`，验收覆盖 `1080 × 2400 @ 420dpi`
- 数据边界：全部为离线 Fake；未连接真实消息、WebSocket、推送或媒体服务

## 验收路径

1. 首页进入消息 Tab，确认默认 `3` 条系统未读与 `2` 条好友未读聚合为 `5`。
2. 通讯录切换聊天列表，打开“卡座搭子”会话，好友未读清零。
3. 验证建联提醒与历史消息从顶部向下排列，输入区固定在底部，不再把历史消息挤在页面底端。
4. 发送 `J04_mock_ok`，新气泡只追加一次并位于最后一条消息之后。
5. 打开聊天详情，验证查找、免打扰、置顶、关系权限和清空记录入口。
6. 长按消息选择转发，进入单选联系人页并打开“发送给 艾琳”确认层。
7. 从会话长按菜单模拟“会话已失效”，验证阻止错误导航；执行本地刷新后恢复原摘要。

## 自动化结果

- 会话列表与异常恢复：5 项通过。
- 单聊发送、失败重试、附件、长消息、引用与撤回、详情：6 项通过。
- 联系人单选转发：1 项通过。
- 通讯录入口、空/错误/离线、隐私搜索、200% 字体与会话失效：7 项通过。
- `flutter analyze`：通过，0 issue。
- `git diff --check`：通过；仅显示现有 Windows LF/CRLF 提示。

## 证据

- `00-home.png`：首页消息徽标入口。
- `01-contacts.png`：通讯录正常态。
- `02-conversations.png`：聊天列表与未读徽标。
- `03-direct-chat.png`：单聊初始消息顺序。
- `04-message-sent.png`：Fake 文本发送后的气泡位置。
- `05-chat-details.png`：聊天详情。
- `06-contact-selector.png`：转发联系人选择。
- `07-forward-confirmation.png`：单人转发确认层。
- `08-conversation-invalid.png`：会话失效保护。
- `09-conversation-recovered.png`：本地恢复后的列表。
- 同名 `.xml`：真机 UI 层级、可点击区域和文本证据。

## 结论

J04 在当前已批准 UI/Fake 范围内通过。重复发送由本地单次插入与同一失败气泡重试覆盖；迟到恢复由 conversation generation 测试覆盖。真实消息顺序、`eventId/messageId` 去重与 WebSocket 乱序收口仍属于后续真实适配阶段，不据此开放生产服务接入。
