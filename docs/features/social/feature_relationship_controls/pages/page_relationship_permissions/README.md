# 关系权限页

- Scope ID：`KC-P-020`
- 文档状态：`In Review`
- 所属功能：[关系控制](../../README.md)
- 路由：`RelationshipPermissionsRoute`，`/social/friend/permissions`，`$extra: SocialTargetRef`
- 设计版本：`Relationship Wireframe v1 / Permissions`
- 最后更新：2026-08-25

## 用户任务与线框

调整与某位好友的交互/内容边界，或明确删除、拉黑及解除拉黑。

```text
[返回]              关系权限

互动范围
(●) 标准互动
( ) 仅聊天

内容
不让对方看我的内容                 [开关]
不看对方的内容                     [开关]

安全
[加入黑名单 / 解除黑名单]
[删除好友]
```

- 置顶、免打扰和聊天记录不在此页。
- 拉黑提示“终止好友关系、取消待处理申请并禁止消息；解除后不恢复好友”。
- 删除提示“只解除好友，不自动拉黑”；两者均需明确二次确认。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
