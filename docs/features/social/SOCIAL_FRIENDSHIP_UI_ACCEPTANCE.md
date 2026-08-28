# 社交好友闭环 UI Mock 验收记录

- 范围：`KC-P-014`～`KC-P-021`
- 验收日期：2026-08-28
- 当前结论：功能与异常流程已完成 UI Mock 实现；真实服务接入保持 `Blocked`
- 视觉基线：旧版小程序源码、既有旧版素材及已保存的 Android 截图

## 已完成页面

1. 通讯录：好友分组、昵称/备注搜索、全部社交出口、空态、失败恢复、离线缓存、关系变更、200% 字体及会话失效。
2. 添加好友入口：扫码入口、不可用分支、短期 Fake 好友二维码、会话失效。
3. 好友申请列表：待处理、空态、局部失败、离线只读、会话失效。
4. 用户主页：好友、陌生人、申请中、被拉黑、本人、离线、临时预览过期、局部失败、不可用及会话失效。
5. 发送好友申请：成功、重复申请、已是好友、结果未知、目标不可用、提交失败及会话失效。
6. 好友备注：编辑、长度限制、只读、保存失败保留草稿及会话失效。
7. 关系权限：权限切换、删除、拉黑、离线只读、写入失败、关系冲突及会话失效。
8. 黑名单：列表、空态、加载失败恢复、离线只读、解除失败及会话失效。

## 路由与安全约束

- 已建立稳定 typed routes：`/social/add`、`/social/requests`、`/social/profile`、`/social/request/send`、`/social/friend/remark`、`/social/friend/permissions`、`/social/blacklist`。
- 页面间只传递本地 Fake `targetRef`；不在 URL 暴露手机号、永久会员号、验证消息或备注。
- 添加好友二维码使用明确不可生产的 Fake 内容，不显示永久会员号或登录凭证。
- 登录失效时停止写操作；涉及验证消息和私有备注的页面清理敏感草稿。
- 删除、拉黑和解除拉黑均有明确确认；解除拉黑不会恢复好友关系。

## 自动验证

- `flutter analyze`：通过，0 issue。
- `flutter test`：通过，207 tests。
- Android 模拟器：`1080 × 2400` 启动 `/social/add` 成功；返回、标题、扫码入口、真实二维码组件和隐私说明均在可视边界内，无黑屏或语义树溢出。
- 新增专项覆盖：
  - `friendship_entry_flow_test.dart`
  - `contacts_flow_test.dart`
  - `send_friend_request_flow_test.dart`
  - `user_profile_flow_test.dart`
  - `relationship_management_flow_test.dart`
  - `social_routes_test.dart`

## 尚未解除的门禁

- `integrationStatus` 继续为 `Blocked`：不得连接真实超级接口、WebSocket、推送或生产 SDK。
- 严格逐像素视觉验收仍需同尺寸旧版运行截图与 Flutter 截图并排复核；仅有源码或单边截图的页面不得宣称视觉 QA 已完全通过。
- 项目级 `UI Flow Approved` 尚未批准，因此本记录不授权真实接口接入。
