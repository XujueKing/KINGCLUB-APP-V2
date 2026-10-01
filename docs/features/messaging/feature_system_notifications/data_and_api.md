# 系统通知数据与 Fake 契约

当前真实契约见 [2026-10-02 业务凭证收件箱](2026-10-02-business-receipt-inbox.md) 及 SystemNoticesRepository：K261002001960 使用本人 noticeRef 游标，K261002001961 使用本人引用或列表序号水位；返回结构为语义 kind/金额分/纯文本明细/受控目标。下列 Fake 契约为旧设计参考，不用于真实付款结果。

```text
NotificationSummary
  notificationRef
  category
  title
  summary
  occurredAt
  isRead
  severity(info|success|warning|critical)
  action?
  notificationVersion

NotificationAction
  none | openOrder | openAssetLedger | openAdmission | openMembershipReview | openLegal
```

```text
NotificationRepository
  loadPage(cursor?, generation)
  refresh(sinceCursor?, generation)
  markRead(notificationRef, expectedVersion, idempotencyKey)
  markAllRead(readThroughCursor, idempotencyKey)
  observeInvalidations(generation)
```

- action 持有受控内存资源引用，不持有 raw URL、完整对象或永久账号。
- UI 只渲染纯文本和稳定字段；未知 category/action 以通用只读卡片失败关闭。
- Fake 覆盖六类通知、重复事件、未读、全读、目标不可用、离线与会话失效。
