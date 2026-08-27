# 会话列表页验收

- [x] 根路由、切换、系统入口、单聊摘要和排序明确
- [x] 搜索、未读、滑动/替代菜单、隐藏和实时合并明确
- [x] 全状态、离线、会话世代、隐私和无障碍明确
- [x] 用户批准按旧版聊天列表进行 UI/Fake 复刻

## UI Mock 实现验收（2026-08-27）

- [x] 通讯录/聊天切换、置顶折叠与两类 Fake 会话已实现
- [x] 未读数字、进入已读和手动标记已读/未读可演示
- [x] 左滑三段操作与长按等价菜单可演示
- [x] 置顶/取消置顶会改变分组与折叠归属
- [x] 删除会话必须二次确认且仅影响当前 Fake 内存
- [x] KING CLUB 行初始系统未读数与系统消息卡片一致
- [x] 单条/全部已读后返回列表立即显示剩余系统未读数
- [x] 好友会话未读变化与系统通知未读共同驱动 Shell 消息徽标，默认总数为 `5`
- [x] 仅进入消息 Tab 或切换通讯录/聊天不会清除 Shell 消息徽标
- [x] 正常聊天首屏保持旧版隐藏搜索，不新增偏离截图的输入框
- [x] 下拉刷新局部失败保留全部摘要与未读，重试后本地恢复 ready
- [x] 删除唯一好友后只保留 KING CLUB 系统入口与纯黑留白
- [x] 离线提示显示 Fake 缓存时间且不改变正常首屏
- [x] 关系结束后摘要只读、清除未读并阻止进入可发送聊天
- [x] 会话失效阻止错误导航，支持本地刷新与返回通讯录
- [x] Fake generation 阻止迟到恢复覆盖更新状态
- [x] 真实 WebSocket、消息存储和服务器调用保持阻断

设备证据：[好友未读状态](android_conversation_unread.png)、[系统三条未读](android_system_unread_three.png)、[系统剩余两条未读](android_system_unread_two.png)、[系统全部已读](android_system_all_read.png)、[Shell 聚合 5 条](../../../../foundation/feature_app_shell/pages/page_app_shell/android_message_badge_five_chat.png)、[Shell 聚合 4 条](../../../../foundation/feature_app_shell/pages/page_app_shell/android_message_badge_four.png)、[Shell 聚合 2 条](../../../../foundation/feature_app_shell/pages/page_app_shell/android_message_badge_two.png)、[Shell 聚合隐藏](../../../../foundation/feature_app_shell/pages/page_app_shell/android_message_badge_zero.png)、[下拉刷新离线保留](android_conversation_offline_refresh.png)、[重试恢复](android_conversation_refresh_recovered.png)、[异常场景长按菜单](android_conversation_scenario_menu.png)、[关系结束只读摘要](android_conversation_relationship_readonly.png)、[只读阻断弹窗](android_conversation_relationship_readonly_dialog.png)、[会话失效摘要](android_conversation_invalid.png)、[失效恢复弹窗](android_conversation_invalid_dialog.png)、[本地恢复](android_conversation_invalid_recovered.png)、[左滑操作](android_conversation_swipe_actions.png)、[长按菜单](android_conversation_long_press_menu.png)、[删除确认](android_conversation_delete_confirm.png)。

当前已覆盖 CONV-M01、M02、M04～M11 的可见或受控 Fake 路径；CONV-M03 搜索因旧版入口硬关闭而暂缓。真实接入保持阻断。
