# 黑名单页

- Scope ID：`KC-P-021`
- 文档状态：`Approved for Development`
- 所属功能：[关系控制](../../README.md)
- 路由：`BlacklistRoute`，`/social/blacklist`，protectedShell/messages 子路由
- 设计版本：`Relationship Wireframe v1 / Blacklist + Legacy Replica Override v1`
- 最后更新：2026-08-27

## 用户任务与线框

查看自己主动拉黑的用户，并在理解后果后解除拉黑。默认可见 UI 以 [旧版复刻基线](legacy_ui_replication.md) 为准。

```text
[返回]              黑名单              [添加]

[头像] 公开昵称  2026-08-20          [switch 开]
       一行公开签名

点击 switch -> 解除确认（不会自动恢复好友）
```

- 列表不显示“添加好友”按钮、永久账号或共同关系。
- 点击行进入 `blockedByMe` 用户主页；解除按钮必须二次确认。
- 200% 字体时列表行自适应增高；状态不只依赖头像或颜色。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
