# 系统通知页

- Scope ID：`KC-P-023`
- 文档状态：`Approved for Development`
- 所属功能：[系统通知](../../README.md)
- 路由：`SystemNotificationsRoute`，`/messages/system`，protectedShell/messages 子路由
- 设计版本：`System Notifications Wireframe v1`
- 最后更新：2026-08-25

## 用户任务与线框

查看可信的通知摘要、管理已读状态，并在允许时进入对应业务页面复核。

```text
[返回]              系统通知              [全部已读]

[账号安全] 登录状态已更新             未读 · 10:20
           请确认是否为本人操作              [展开]

[订单支付] 订单状态已变化                  昨天
           前往订单详情查看最新结果             [查看]

[平台通知] 服务维护提醒                    周一
           预计维护时间……
```

- 卡片用固定类别、纯文本和稳定状态，不渲染任意 HTML。
- 通知里的金额/结果不是账本或订单事实；动作目标重新加载权威数据。
- “全部已读”只影响阅读状态，不删除记录。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
