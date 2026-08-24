# 好友备注页

- Scope ID：`KC-P-019`
- 文档状态：`Approved for Development`
- 所属功能：[关系控制](../../README.md)
- 路由：`FriendRemarkRoute`，`/social/friend/remark`，`$extra: SocialTargetRef`
- 设计版本：`Relationship Wireframe v1 / Remark`
- 最后更新：2026-08-25

## 用户任务与线框

设置仅自己可见的好友备注名和说明，并查看关系来源与添加时间。

```text
[返回]              好友备注                   [保存]

备注名（0/24）     [________________]
说明（0/120）      [________________]
                    [________________]

更多信息
来源                当面扫码
添加时间            2026-08-25
```

- 不提供电话字段、联系人权限、分组或标签。
- 来源为清洗类别、添加时间为只读；私有备注不展示给对方。
- 字段有持久标签和计数，200% 字体下可滚动且不被键盘遮挡。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
