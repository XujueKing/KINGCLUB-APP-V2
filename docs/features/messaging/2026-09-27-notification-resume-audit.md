# 通知与前台恢复核对

## 当前实现

- `app.dart` 在 resumed 时恢复推送注册、单聊/群聊来电收件箱并同步实时连接；后台暂停相应拉取。
- `ConversationsPage` resumed 时重新绑定登录态或刷新列表。首页的 IndexedStack 已创建聊天页面，因此并非一定要先手动打开聊天标签才具备同步入口。
- 单聊/群聊来电收件箱以代次丢弃退出前台或注销后的迟到响应；前台恢复后再次读取当前邀请。它们不替代 Android 在进程不存在时接收厂商通知。

## 本轮自动化

`foreground_call_inbox_test.dart`、`foreground_group_call_inbox_test.dart`、`push_registration_runtime_test.dart`、`conversations_relay_unread_widget_test.dart`、`conversation_relay_unread_test.dart`、`session_registration_restore_test.dart` 共 45 项通过。

涵盖迟到来电、重复展示控制、后台/恢复时重试、旧账号绑定隔离、中继与服务端未读合并及登录恢复。认证模块只执行既有回归，没有修改既有验证窗口或登录规则。

## 真机未完成项

尝试准备双机进程恢复场景时，A 当前前台为系统电话应用，停止操作并请求用户确认可继续。B 退后台后 `am kill` 未结束正式包进程，PID 仍存在，因此不能记作系统回收或进程结束测试；随后已将 B 正式聊天包恢复前台。本轮未发送该恢复场景的新消息，也没有强制结束 A 电话应用。

当前仍需区分：前台恢复逻辑的自动化已通过，普通 OPPO 通知仅首条定向通知有真实展示证据；进程回收后的通知、锁屏新来电和通知对应内容的完整真机恢复仍未验收。普通通道限制及待用户决定的通道方案沿用 `2026-09-27-oppo-push-delivery.md`，未擅自申请 IM/私信通道。
