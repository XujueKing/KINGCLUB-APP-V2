# 用户主页数据与 Fake 契约

```text
PublicMemberProfile
  targetRef
  publicNickname
  avatarRef?
  verifiedBadge
  bio?
  cityLabel?
  districtLabel?
  occupation?
  heightCm?
  preferenceLabels[]
  relationshipState
  allowedActions[]
  profileVersion
  relationshipVersion
  requestContext?
```

```text
UserProfileRepository
  load(targetRef, requestRef?, generation)
  refresh(targetRef, expectedVersions?, generation)
```

- allowedActions 是展示约束，不替代服务端在每个命令上的授权。
- `avatarRef` 通过媒体 adapter 解析，原始存储地址不进入日志或埋点。
- 缓存只保存清洗投影并按会话世代隔离；短期 invite 预览默认不落盘。
- Fake 覆盖所有关系状态、字段缺失、局部媒体失败、权限变化和目标不可用。
