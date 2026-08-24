# 实名与成年核验页状态

| 状态 | UI | 动作 |
|---|---|---|
| `editing` | 姓名、掩码证件号、告知勾选 | 校验后开始 |
| `starting` | 表单锁定、按钮 loading | 禁止重复 |
| `verifying` | 核验方/Fake 流程与安全说明 | 按契约取消或等待 |
| `processing` | “结果确认中” | 查询状态，不重复提交 |
| `verifiedAdult` | 成功摘要 | 自动/按钮进入下一步 |
| `ageRestricted` | 成年条件未满足说明 | 退出登录；清理输入 |
| `retryableFailure` | 稳定原因与重试 | 重试或编辑 |
| `manualReview` | 人工处理中说明 | 进入 KC-P-009 或刷新 |
| `offline` | 保留非敏感 UI，不提交 | 网络恢复后重试 |
| `sessionLost` | 清理字段和核验引用 | reset 登录 |

失败、取消和 App 后台返回必须收敛到唯一状态，不能同时保留 loading 与可提交按钮。
