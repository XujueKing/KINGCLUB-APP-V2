# 通讯录数据与 Fake 契约

```text
ContactSummary
  memberRefId          不透明资源引用，不是 userAccount
  displayName          优先自己的备注，否则公开昵称
  publicNickname
  avatarRef?
  verifiedBadge
  sectionKey           A-Z 或 #
  relationshipVersion

ContactsSnapshot
  items[]
  incomingRequestCount
  nextCursor?
  snapshotVersion
  refreshedAt
```

```text
ContactsRepository
  watchCachedSnapshot(generation)
  loadFirstPage(query?, generation)
  loadNextPage(cursor, query?, generation)
  refresh(query?, generation)
```

- `query` 去首尾空白后最长 40 字符；空值恢复完整列表。
- 分页使用不透明 cursor，不使用页码推断新增/删除关系。
- Fake 必须内置稳定名单、空列表、搜索无结果、分页、局部头像失败、离线缓存、好友被删除和会话失效。
- 真实超级接口 ID 尚未设计；页面不得直接依赖超级接口 envelope。
