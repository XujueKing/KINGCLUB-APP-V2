# VIP 组局数据与 Fake 契约

```text
PartySummary
  partyRef, serviceDay, hostPublicProfile
  title, packageSummary, costPolicy, visibility
  capacityBucket, availabilityState, status
  memberPrice?/hostCommitment?, ruleSummary[]

PartyDetail
  summary, termsSnapshotRef, allowedActions[]
  participantCountBucket
  memberProjection?       // 仅 confirmed participant/host
  currentViewerRole
  currentViewerMembershipStatus?

PartyDraftQuote
  draftRef, revision, expiresAt
  tableOfferRef, packageOfferRef, capacity
  costPolicy, visibility
  hostDueNow, memberDueWhenJoining?
  lineItems[], termsSnapshotRef, allowedActions[]

PartyManagementProjection
  partyRef, version, status, recruitmentState
  participants[], invitations[], consumerOrderSummary
  allowedActions[]
```

```text
VipPartyRepository
  loadBrowse(serviceDate?, partyRef?, generation)
  loadParty(partyRef, generation)
  createJoinIntent(partyRef, termsSnapshotRef, idempotencyKey)
  reconcileJoin(idempotencyKey)
  createDraft(serviceDayRef, idempotencyKey)
  requoteDraft(draftRef, revision, configurationRefs, idempotencyKey)
  createParty(draftRef, revision, termsSnapshotRef, idempotencyKey)
  reconcileCreate(idempotencyKey)
  loadManagement(partyRef, generation)
  setRecruitment(partyRef, expectedVersion, open, idempotencyKey)
  createInvite(partyRef, targetMemberRef, expectedVersion, idempotencyKey)
  revokeInvite(inviteRef, expectedVersion, idempotencyKey)
  releaseUnpaidHold(memberRef, expectedVersion, idempotencyKey)
```

- 身份和 host 权限来自会话及服务端投影，不接受 `userAccount/power`。
- 金额使用 `Money(currency, minorUnits)`，费用策略切换必须整份重报价。
- `allowedActions + expectedVersion` 控制管理写操作；同一幂等键返回同一结果。
- 公开列表不返回成员数组；受邀/成员信息按最小权限投影。
- Fake 阶段不调用旧超级接口、支付、推送或消息服务。
