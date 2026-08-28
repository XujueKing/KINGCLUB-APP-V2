# AA 确认订单页

- Scope ID：`KC-P-029`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[一起玩 AA 预订](../../README.md)
- 旧版来源：`order2`
- 路由：`AaOrderConfirmationRoute`，`/club/aa/confirm`，`$extra: AaQuoteRef`
- 设计版本：`AA Reservation Legacy Replica v2 / Confirmation`
- 最后更新：2026-08-28

## 用户任务与旧版版式

核对服务端最新报价、选择允许的抵扣、确认规则，并创建一张短时占位的待支付订单。

```text
[旧版返回箭头]          确认订单
[深色分区：位置 / 时间 / 套餐 / AA人次价]
[深色分区：优惠券 / 金币方案 / 余额方案]
[深色分区：微信支付外观，仅 Fake]
[规则确认与报价倒计时]

[粉金固定底栏：实付金额]                 [立即付款]
```

- 复刻旧版 `order2` 的分区行、粉金强调色和固定付款底栏，但不允许手输金币或余额金额。
- 抵扣选项触发本地 Fake 重新报价；报价变化后清除规则勾选。
- “立即付款”只生成 Fake 待支付结果并显示支付模块未接入说明，不拉起微信支付。

- 每次抵扣变更都显示刷新状态，并用新的 `quoteRevision` 替换整份金额明细。
- 不允许手输余额/金币金额；采用服务端给出的可选方案或“最多可抵扣”选项，降低输入和舍入错误。
- 提交成功只表示获得 `pendingPayment` 或免付确认结果；不得在本页宣告第三方支付成功。
- 0 元订单按钮文案为“确认预订”，仍由服务端创建并确认订单，不能客户端直接成功。
- 规则勾选绑定 `termsSnapshotRef`；报价/规则更新后必须重新确认。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。

## Android UI/Fake 实现证据

- 2026-08-27 已验证旧版确认订单分区、优惠券/金币/余额 Fake 重报价、规则确认、固定实付底栏和 Fake 待支付结果。
- 截图：[android_aa_confirmation_legacy_replica_v2.png](android_aa_confirmation_legacy_replica_v2.png)
- Fake 待支付结果：[android_aa_fake_pending_payment.png](android_aa_fake_pending_payment.png)
- 报价失效：[android_aa_quote_expired.png](android_aa_quote_expired.png)
- 提交时售罄：[android_aa_submission_sold_out.png](android_aa_submission_sold_out.png)
- 已有预订：[android_aa_submission_duplicate.png](android_aa_submission_duplicate.png)
- 提交结果未知：[android_aa_submission_result_unknown.png](android_aa_submission_result_unknown.png)
- 资格失效：[android_aa_confirmation_ineligible.png](android_aa_confirmation_ineligible.png)
- 离线只读：[android_aa_confirmation_offline.png](android_aa_confirmation_offline.png)
- 会话失效安全清理：[android_aa_confirmation_session_invalid.png](android_aa_confirmation_session_invalid.png)
- 首次加载：[android_aa_initial_loading.png](android_aa_initial_loading.png)
- 重报价锁定：[android_aa_requote_loading.png](android_aa_requote_loading.png)
- 报价更新：[android_aa_quote_changed.png](android_aa_quote_changed.png)
- 无效报价引用：[android_aa_invalid_ref.png](android_aa_invalid_ref.png)
- 零元确认：[android_aa_zero_cash.png](android_aa_zero_cash.png)
- 零元确认结果：[android_aa_zero_cash_confirmed.png](android_aa_zero_cash_confirmed.png)
- 点击“立即付款”只显示本地 Fake 待支付订单，不调用微信支付、超级接口或任何生产服务。
- 本轮验收截图：[确认订单](../../qa/2026-08-28/03-confirm.png)、[Fake 待支付结果](../../qa/2026-08-28/04-fake-result.png)；抵扣项同时补齐 Android 读屏标签。

## 报价失效 Fake 状态补充

- 不增加常驻测试按钮，长按“确认订单”标题打开本页 Fake 状态面板，可选择正常提交、报价失效、提交时售罄、已有预订、结果未知、资格失效、离线和会话失效。
- 报价失效后在金额区上方显示旧版粉金警示条，抵扣、规则确认和“立即付款”全部禁用。
- 用户只能点“刷新报价”恢复新的 Fake 报价；刷新后清除规则勾选并要求重新确认。
- 该流程只修改本地 Fake 状态，不请求超级接口、不创建订单，也不拉起支付。

## 提交异常 Fake 状态补充

- `soldOut`：提交等待结束后显示“套餐刚刚售罄”，明确未创建订单、不会扣款；底部按钮锁定为“已售罄”，只允许返回 AA 套餐列表刷新。
- `duplicateActiveReservation`：显示已有 Fake 预订编号、待支付状态和占位剩余时间；不创建第二张订单，底部按钮锁定为“已有预订”，可返回列表查看。
- `resultUnknown`：显示“预订结果待确认”，明确禁止重复提交或支付；继续查询必须复用同一 Fake 幂等键，并在本地对账为一张待支付订单。
- 三种异常均以确认页内联状态承载，不使用一闪而过的 SnackBar；返回、查询和恢复路径在窄屏滚动布局中始终可达。
- 所有异常只在内存中模拟，不访问超级接口、WebSocket、订单、库存或支付服务。

## 资格、网络与会话 Fake 状态补充

- `ineligible`：提交后显示稳定资格原因，明确没有创建订单和扣款；清除规则勾选并锁定抵扣及付款，只允许返回 AA 列表。
- `offline`：保留当前报价作为只读缓存，抵扣、规则和付款全部禁用；“恢复联网”只恢复本地默认报价并要求重新确认规则。
- `sessionInvalid`：立即移除订单摘要、金额、抵扣、报价倒计时和提交上下文，只显示安全说明与“返回登录”；正式 App 由全局路由 reset 到手机号登录，不能返回原业务栈。
- 会话 reset 只发出 Fake 导航意图，不访问真实会话服务，也不保留可恢复的报价或幂等上下文。

## 加载、重报价、无效引用与零元确认

- `initialLoading` 使用独立加载内容替换金额和抵扣区，底部金额显示 `--`、主按钮显示“加载中”且不可提交；Fake“完成加载”回到一份全新的正常报价。
- 用户切换优惠券、金币或余额时先进入 `requoteLoading`：保留旧金额并显示“正在重新计算报价”，抵扣和提交暂时锁定。
- 重报价完成后再一次性替换抵扣与实付金额，显示“报价已更新”，并清除规则勾选；用户确认提示后才按新金额继续。
- `invalidRef` 不展示旧套餐、抵扣、金额或付款按钮，只说明报价引用无法继续使用，并返回套餐详情重新获取。
- `zeroCash` 显示实付 `¥0.00`，主按钮改为“确认预订”，底栏明确“无需调用支付”；提交结果只表示 Fake 免付预订已确认，不宣称支付成功。
- 以上状态均只使用本地 Fake 数据，不调用超级接口、支付或生产服务。
