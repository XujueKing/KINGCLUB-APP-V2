# VIP 组局创建页交互

| 触发 | 行为 |
|---|---|
| 选择桌位/套餐/人数 | 更新配置引用并 `requoteDraft` |
| 切费用策略/可见性 | 重报价并刷新规则摘要 |
| 查看规则 | 打开当前 terms snapshot |
| 确认创建 | 稳定幂等键 + revision + termsSnapshotRef 提交 |
| 提交超时 | `reconcileCreate`，禁止新建幂等键 |
| 返回/取消 | 未提交可确认放弃本次会话草稿 |
| 返回 pendingHostPayment | `openPayment(PaymentIntentRef)` |
| 返回 confirmed | replace 到 `VipPartyManagementRoute(PartyRef)` |

- 表单变更采用防抖/SingleFlight；迟到报价不能覆盖新配置。
- 不把配置、金额或身份放入路由、日志和分析事件。
- 服务端返回字段级稳定错误，UI 聚焦首个错误并保留其他选择。
- 大字体下单选项和报价明细纵向排列，底部按钮不遮挡规则。
