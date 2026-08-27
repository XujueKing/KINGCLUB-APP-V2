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

## Fake 场景入口

| 场景 | 可见结果 |
|---|---|
| `ready` | 默认旧版表单、有效报价、可创建 |
| `quoteChanged` | 展示旧/新金额差异，规则勾选清空 |
| `quoteExpired` | 底部按钮变为刷新报价，刷新后恢复 |
| `inventoryConflict` | 桌位冲突提示，保留套餐与人数，要求重选桌位 |
| `offline` | 显示离线提示，选择、重报价和创建全部禁用 |
| `resultUnknown` | 提交后显示对账中说明，只允许用原幂等键继续查询 |

这些状态均为本地 Fake；页面不得把“待支付”展示成“已付款”。
