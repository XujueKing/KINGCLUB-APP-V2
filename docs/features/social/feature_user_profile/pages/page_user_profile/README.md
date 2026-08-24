# 用户主页

- Scope ID：`KC-P-017`
- 文档状态：`In Review`
- 所属功能：[统一用户主页](../../README.md)
- 路由：`UserProfileRoute`，`/social/profile`，`$extra: SocialTargetRef + FriendRequestRef?`
- 设计版本：`Social User Profile Wireframe v1`
- 最后更新：2026-08-25

## 用户任务与导航

确认对方是谁、查看允许公开的资料，并根据当前关系执行唯一正确的下一步。入口来自通讯录、申请列表或短期二维码预览；引用失效时安全返回来源。

## 线框

```text
[返回]              用户主页                   [更多]

             [头像]
           公开昵称  [会员认证]
             一句话简介
        城市区域 · 职业 · 身高（有值才显示）
        [兴趣偏好标签……]

[关系上下文：验证消息 / 等待状态（按需）]

[主动作：发送申请 / 接受 / 发消息 / 查看状态]
[次动作：拒绝 / 好友备注 / 关系权限（按需）]
```

- 不展示账号、手机号、实名、年龄、IP、收入、颜值、粉丝统计或作品列表。
- “更多”只在好友/拉黑语境提供备注或关系权限，不接收服务端动态菜单。
- 200% 字体时标签换行、动作纵向排列；头像和认证有文字替代。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
