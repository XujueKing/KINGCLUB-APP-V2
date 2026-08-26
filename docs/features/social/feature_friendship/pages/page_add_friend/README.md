# 添加好友入口页

- Scope ID：`KC-P-015`
- 文档状态：`Approved for Development`
- 所属功能：[好友申请与添加](../../README.md)
- 路由：`AddFriendRoute`，`/social/add`，protectedShell/messages 子路由
- 设计版本：`Friendship Wireframe v1 / Add / Legacy Add Friend Replica v1`
- 最后更新：2026-08-26

## 用户任务与线框

选择当面扫码或出示自己的短期二维码，不在此页输入账号或手机号。

```text
[返回]              添加好友

[扫一扫]
扫描对方 KingClub 短期二维码

[我的二维码]
让对方扫描我的短期二维码

扫码不会自动添加好友，双方仍需确认
```

- “扫一扫”发出 `openSafeScanner(friendInvite)`；“我的二维码”发出 `openPersonalQr`。
- 本页无相机画面、二维码载荷、搜索框和权限申请。
- 两张动作卡在 200% 字体下纵向扩展，说明和动作名均可读。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## 2026-08-26 旧版复刻变更

用户要求继续按旧版复刻；本轮以 [旧版“添加朋友”UI 复刻规范](legacy_ui_replication.md) 为准，恢复旧版扫一扫菜单、页面内大号二维码和 Fake 会员码。二维码不含真实身份载荷。
