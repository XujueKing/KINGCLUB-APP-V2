# 黑名单页

- Scope ID：`KC-P-021`
- 文档状态：`Approved for Development`
- 所属功能：[关系控制](../../README.md)
- 路由：`BlacklistRoute`，`/social/blacklist`，protectedShell/messages 子路由
- 设计版本：`Relationship Wireframe v1 / Blacklist`
- 最后更新：2026-08-25

## 用户任务与线框

查看自己主动拉黑的用户，并在理解后果后解除拉黑。

```text
[返回]              黑名单
[搜索昵称________________________]

[头像] 公开昵称                       [解除]
       拉黑于 2026-08-20

解除拉黑不会自动恢复好友关系
```

- 列表不显示“添加好友”按钮、永久账号或共同关系。
- 点击行进入 `blockedByMe` 用户主页；解除按钮必须二次确认。
- 200% 字体时动作移到下一行；状态不只依赖头像或颜色。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
