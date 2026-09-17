# 报名分座、出库与 AA 退款：字段及操作契约 v0.1

后续细化见 [数据库约束与接口校验](DATABASE_AND_VALIDATION.md) 与 [请求结构草案](contracts/core-request-shapes.json)。请求体仍需业务层校验，结构文件未注册；其候选份数/批量上限不是活动报名总人数限制。

2026-09-18，In Review。所有字段、约束和请求示例为设计建议，未注册接口、未创建表或导入数据。以 [已确认营业规则](CONFIRMED_OPERATING_RULES.md) 为业务依据。

## 1. 与当前服务接轨的证据

本轮只读核对 `ccsop-service/src/super-interface/types.ts` 与 `routes.ts`：解密后的业务请求采用 `interfaceId / params / options`，路由相对路径为 `/supper-interface`；接口 ID 校验为大写字母加 6–64 位数字。执行上下文已有 requestId、userAccount、sessionId、businessLine 等。加密外层为 data/sign，受现有握手或 API key 校验约束，不能另造明文生产入口。

下列示例只是 **params 和业务结果体**，不是完整线上请求或现有响应包装。语义操作名不得填进 interfaceId；正式编号须后端独立工作区核对元数据后分配。业务幂等键拟用 `commandId`，与传输层 `x-request-id` 区分：网络重试遵守现有防重放协议，业务意图仍复用 commandId，不绕过 nonce/签名校验。

另只读核对 `database/mysql8/031_kingclub_private_storage.sql`：保管记录使用 itemRef、userAccount、productKey、quantity、remainingPercent、version。新文档的会员/商品引用需映射这些现有键，不能把语义名称当作可直接替换的真实字段。此处仅核对该文件，非全部后续迁移的最终结构审计。

## 2. 公共字段字典

| 字段 | 拟定类型/约束 | 规则 |
|---|---|---|
| publicRef、各 *Ref | UTF-8 字符串，1–64 字符 | 不透明引用；具体来源 ID 长度适配时再核对 |
| commandId | UUID 字符串 | 一次意图唯一，重试不变；同键不同内容拒绝 |
| tenantRef / storeRef | 引用，必填 | 服务端核实从属和权限，禁止凭客户端声明授权 |
| version / expectedVersion | 正整数，接口范围 ≤ 2^31−1 | 并发比对；溢出策略需正式实现定稿 |
| memberRef / actorRef | 引用 | 会员本人/实际操作人从会话取得；管理员分座可提交目标报名 ID |
| amountMinor | 非负安全整数，币种最小单位 | DTO 上限 ≤ 2^53−1；业务支付上限另配。不得浮点分摊 |
| quantity | 非负十进制字符串，建议最多 6 位小数 | 写入通常要求 >0；盘点可为 0；每商品精度/单位校验 |
| deltaQuantity | 有符号十进制字符串 | 仅流水计算结果；客户端不能任意调总库存 |
| instant | RFC3339 UTC 时间 | 存服务端时点，按门店时区展示；营业日单独派生 |
| reason | 字符串，建议 1–500 字符 | 取消、更正、人工退票必填，禁止写秘密凭据 |

必填字段缺失或 null 拒绝；可选字段省略与清空语义需逐接口指定，不自动互换。字符串长度、金额业务上限、数据库精度是待审默认值，不声称已获用户批准。

## 3. 报名与分座对象

| 对象 | 最少业务字段 | 唯一性/事务约束建议 |
|---|---|---|
| ActivityRegistration | registrationRef、tenantRef、storeRef、activityRef、memberRef、entitlementRef、state、version、createdAt | 同一会员在同一活动只保留一条当前有效报名；历史失效另保留 |
| TableSession | tableSessionRef、tableRef、activityRef、startAt、configVersion、minSeats、maxSeats、genderRuleSnapshot、state、version | 卡座占用时间不能重叠；活动可对应多桌，不限制活动报名数 |
| CurrentSeatAssignment | registrationRef、tableSessionRef、assignedAt、actorRef、version | 同一报名仅一条当前有效分配；变更历史追加保存 |
| SharedPackageFulfillment | fulfillmentRef、tableSessionRef、recipeVersion、state、issueRef | 每次卡座开台一份基础套餐履约，不能按 activityRef 唯一 |

分座事务建议：按稳定 ID 顺序锁目标卡座本次开台及报名，核对原分配/有效权益、门店、人数与配比，写当前分配与历史；换桌同时锁旧/新桌，原子释放旧位并占新位。容量计数必须基于事务内有效分配，不能只做先 count 再无锁 insert。人数不足可保留分座方案，但禁止开台；自动分座预览不承诺占位。

ConfirmSeatAllocation 的合成 params：

```json
{
  "commandId": "11111111-1111-4111-8111-111111111111",
  "tenantRef": "demo-tenant", "storeRef": "demo-store",
  "activityRef": "demo-activity",
  "tableSessions": [{"tableSessionRef": "demo-session", "expectedVersion": 3}],
  "assignments": [{"registrationRef": "demo-registration", "expectedVersion": 1, "tableSessionRef": "demo-session"}]
}
```

业务结果示例：

```json
{"operationRef":"demo-allocation","status":"confirmed","assignments":[{"registrationRef":"demo-registration","tableSessionRef":"demo-session","version":2}],"tables":[{"tableSessionRef":"demo-session","assignedCount":6,"minSeats":6,"maxSeats":10,"canOpen":true,"version":4}]}
```

此例假设该桌原有 5 人；canOpen 仅表示人数/分座条件满足，确认开台时仍核对库存及业务状态。示例是一次分配提交，不代表只准分一人或一桌。报名本身用 JoinActivity，params 为 commandId、storeRef、activityRef、entitlementRef；memberRef 取会话，返回 registrationRef/state/version，不要求 tableRef。

## 4. 预留与出库

| 对象 | 关键字段 | 约束 |
|---|---|---|
| StockBatch | batchRef、storeRef、locationRef、productRef、unit、onHandQuantity、unitCost、currency、version | 批次进价不可被最新价覆盖 |
| StockReservation | reservationRef、sourceType/sourceRef、expiresAt、state、version | 明细引用原料/批次及数量；所有销售模式共享可售约束 |
| InventoryIssue | issueRef、sourceType/sourceRef、state、confirmedAt、actorRef | 同一业务出库来源唯一；不可直接删除已确认单 |
| InventoryMovement | movementRef、issueRef/receiptRef、batchRef、quantity、unit、costSnapshot、reversalOf | 追加/冲正，批次量与流水同事务一致 |

确认开台 params 示例：

```json
{"commandId":"22222222-2222-4222-8222-222222222222","storeRef":"demo-store","tableSessionRef":"demo-session","expectedVersion":4,"expectedRecipeVersion":2}
```

业务结果示例：

```json
{"operationRef":"demo-opening","status":"confirmed","tableSessionRef":"demo-session","version":5,"fulfillmentRef":"demo-package","issueRef":"demo-issue","deliveryState":"pending","lines":[{"productRef":"demo-beer","quantity":"12","unit":"bottle","costMinor":12000,"currency":"CNY"}]}
```

出库数由套餐快照计算，客户端不得传任意扣库数。合并同款组成，按统一顺序锁原料及分配批次，验证可用量和预留归属，一次转换预留/写出库/扣批次/写成本来源。缺一项整笔不出库；派发备酒通知用可靠待办，通知失败不再扣一次。

上桌只更新交付数量。直接支付成功与 AA 成团使用同一库存服务的来源约束，但各自业务来源不同；商品支付回调不能误用开台接口出第二套。库存不足返回 STOCK_INSUFFICIENT，并附缺量商品，不返回半成功整桌套餐。

## 5. AA 与余额退款

| 对象 | 字段 | 不变量 |
|---|---|---|
| AAGroup | groupRef、storeRef、initiatorRef、shareCount、totalMinor、currency、createdAt、expiresAt、state、version、reservationRef | 创建成功起 30 分钟；人数与价格快照不静默改 |
| AAShare | shareRef、groupRef、shareIndex、amountMinor、payerRef、paymentRef、state | groupRef+shareIndex 唯一；未付不计已付份额 |
| PaymentFact | paymentRef、channelRef、externalTransactionRef、payerRef、amountMinor、currency、confirmedAt | 渠道实收唯一去重，不能凭客户端声明成功 |
| RefundIntent | refundRef、paymentRef、reason、destination、amountMinor、state、version | 同一退款原因/原支付唯一；累计不超过可退实收 |
| WalletEntry | entryRef、refundRef、issuerRef、memberRef、amountMinor、currency | refundRef 唯一入账，收款人必须原付款会员 |

CreateAAGroup params 示例（quoteRef 冻结购物车及优惠，不由客户端传总价）：

```json
{"commandId":"33333333-3333-4333-8333-333333333333","storeRef":"demo-store","tableSessionRef":"demo-session","quoteRef":"demo-quote","expectedQuoteVersion":1,"shareCount":3}
```

结果示例：

```json
{"groupRef":"demo-aa","status":"collecting","totalMinor":30000,"currency":"CNY","shareAmountsMinor":[10000,10000,10000],"createdAt":"2026-09-18T12:00:00Z","expiresAt":"2026-09-18T12:30:00Z","version":1}
```

发起人不自动计已付；按最小货币单位分摊尾差，份额之和等于应收。代付多份及发起人是否必须认领仍待交互规则，不以字段设计默认批准。

到期任务是服务端内部动作，不允许会员提交任意 payerRef/退款金额。建议顺序：锁团，核对服务端到期和付款事实；若已成团返回原状态，否则关闭收款入口、释放预留、为已确认付款创建退款待办。迟到实收同样关联该关闭团创建原付款退款，不能复活。

余额退款事务锁原支付可退额度和目标主体会员余额，写唯一退款流水并增加余额；同事务成功后退款才为 succeeded。两个付款各 100 元的查询结果示例（仅管理员有权完整查看；会员查询只返回本人项）：

```json
{"groupRef":"demo-aa","status":"closed","issueRef":null,"refunds":[{"refundRef":"demo-refund-a","paymentRef":"demo-pay-a","amountMinor":10000,"currency":"CNY","destination":"app_balance","status":"succeeded"},{"refundRef":"demo-refund-b","paymentRef":"demo-pay-b","amountMinor":10000,"currency":"CNY","destination":"app_balance","status":"succeeded"}]}
```

若一笔入账失败，团保持 refunding，不给全成功回执。退款到余额不删除原外部收款、不同时发原路退款；原外部结算与新钱包负债分别保留。

## 6. 错误样例和验证门槛

```json
{"status":"rejected","error":{"code":"VERSION_CONFLICT","reasonKey":"commerce.object_changed","objectRef":"demo-session","currentVersion":5,"retryAction":"reload_and_confirm"}}
```

统一错误语义沿 [基础约定](CONTRACT_BASELINE.md)，此体不替换现有 HTTP/加密响应包装。请求未知须先查原 commandId；查无结果仍需由执行记录裁决是否安全重试，不用新键赌博。

后续必须验证：同键异内容拒绝、同报名并发分两桌、最后一份库存跨套餐争抢、开台重试、最后 AA 付款与到期竞态、退款入账后响应丢失、迟到支付重复通知、同名跨店 ID 和会员越权查询。以上为设计测试清单，未执行。正式 DDL/索引、锁顺序实现、金额上限、JSON Schema 与接口注册仍待完成。
