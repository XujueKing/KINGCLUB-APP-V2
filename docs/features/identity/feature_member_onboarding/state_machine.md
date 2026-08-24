# 会员准入状态机

- 文档状态：`In Review`

```text
identityRequired
  -> identityProcessing
  -> identityVerified
  -> imagesRequired
  -> preferencesRequired
  -> readyToSubmit
  -> submitting
  -> pendingReview
      -> approved
      -> changesRequired -> 指定步骤 -> pendingReview
      -> rejected
approved -> suspended（后续权威状态变化）
```

| 状态 | Shell 权限 | 可编辑范围 |
|---|---|---|
| identityRequired/Processing | 否 | 实名步骤，Processing 只允许查询/取消供应商流程 |
| imagesRequired | 否 | 两个图片槽位 |
| preferencesRequired/readyToSubmit | 否 | 偏好与未锁定资料 |
| submitting | 否 | 全部锁定，防重复提交 |
| pendingReview | 否 | 默认只读 |
| changesRequired | 否 | 仅 `editableSections` |
| approved | 是 | 准入资料改动转个人资料规则，不回 onboarding |
| rejected | 否 | 仅当 `canResubmit=true` 且到达 `resubmitAfter` 才可重提 |
| suspended | 否 | 只读状态、退出和批准的客服入口 |

## 不变量

- `kycStatus=verified` 不能推导 `membershipStatus=approved`。
- 客户端不自行推进 currentStep；每次写入后使用服务端返回的 snapshot/version。
- 最终提交使用 idempotencyKey；结果未知必须查询状态，不能显示成功或重复建申请。
- approved 只来自权威 snapshot；缓存状态不得授予 Shell 权限。
