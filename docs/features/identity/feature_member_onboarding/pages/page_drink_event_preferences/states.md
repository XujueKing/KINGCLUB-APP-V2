# 酒类与活动偏好页状态

| 状态 | UI/处理 |
|---|---|
| `loadingCatalog` | 目录骨架 |
| `ready` | 可多选、跳过并提交 |
| `savingDraft` | 保存 optionId 与目录版本 |
| `submitting` | 全页锁定，单一幂等提交 |
| `resultUnknown` | 显示“正在确认”，查询 snapshot |
| `incomplete` | 按 missingSections 提示/跳转 |
| `catalogStale/versionConflict` | 刷新目录/snapshot 后再确认 |
| `error/offline` | 保留选择并允许重试，不显示成功 |
| `sessionLost` | 清理并 reset 登录 |

`APPLICATION_ALREADY_SUBMITTED` 收敛到 review 状态，不作为错误 Toast。
