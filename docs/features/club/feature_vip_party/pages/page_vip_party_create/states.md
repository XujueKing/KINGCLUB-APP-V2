# VIP 组局创建页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 表单/报价骨架 |
| `draftReady` | 配置可编辑，报价有效 |
| `requoteLoading` | 保留选择，提交禁用 |
| `quoteChanged` | 显示差异并清除规则同意 |
| `quoteExpired` | 强制刷新后再提交 |
| `submitting` | 防重复，显示正在创建 |
| `resultUnknown` | 用原幂等键对账 |
| `pendingHostPayment` | 显示占位到期并进入支付 |
| `confirmed` | 跳转局长管理页 |
| `inventoryConflict` | 保留合法选择，提示重新选桌/套餐 |
| `ineligible` | 禁止创建并说明稳定原因 |
| `validationError` | 定位到具体字段，不清空整表 |
| `offline` | 草稿仅本次会话可见，禁止重报价/提交 |
| `sessionInvalid` | 清空草稿、报价、幂等键并 reset |

报价 revision、规则 snapshot 或 generation 变化后，旧同意状态不得复用。
