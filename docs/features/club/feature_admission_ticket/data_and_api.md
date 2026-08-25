# 入场凭证数据与 Fake 契约

```text
AdmissionRef
  refId, generation, expiresAt?

AdmissionProjection
  admissionRef
  orderRef
  credentialVersion
  status
  eventTitle
  serviceDay
  venueAreaLabel
  packageSummary?
  displayWindow
  entryAt? / exitAt?
  allowedActions[]
  assistanceMessage?

AdmissionDisplayToken
  opaqueToken
  expiresAt
  refreshAfter
  tokenVersion

ScanContextRef
  refId, generation, kind=admissionContext, expiresAt
```

```text
AdmissionRepository
  loadCredential(admissionRef, scanContextRef?, generation)
  issueDisplayToken(admissionRef, credentialVersion, idempotencyKey)
  refreshDisplayToken(admissionRef, tokenVersion, idempotencyKey)
  confirmExit(admissionRef, scanContextRef, expectedVersion, idempotencyKey)
  reconcileExit(idempotencyKey)
```

- 认证身份来自会话，AdmissionRef 必须属于当前会员；请求不接受 userAccount/memberId/订单 JSON。
- token 是服务端签发的不透明值；Flutter 只负责渲染，不解析、不拼接、不落盘。
- `refreshAfter < expiresAt`，轮换失败时旧码最多显示到其权威过期时间，随后立即遮盖。
- `credentialVersion` 变化会使旧 token 失效；所有状态写入由服务端事务和审计记录完成。
- Fake 只模拟时间推进、签发、核验事件和离场确认，不调用真实二维码、超级接口或验票端。
