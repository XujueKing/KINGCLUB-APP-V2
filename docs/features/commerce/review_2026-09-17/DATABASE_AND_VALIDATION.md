# 数据库约束与接口校验设计 v0.1

响应与恢复细化见 [状态转换设计](STATE_AND_RECOVERY.md)。退款工作者不在持有钱包锁后反向锁团/库存；groupState 与 refundState 分离，避免迟到付款造成“已关闭团重新成团”的歧义。

日期：2026-09-18。In Review，仅文档；没有执行 DDL、迁移、真实请求或数据库测试。承接 [核心数据契约](CORE_DATA_CONTRACTS.md)。下列名称为逻辑对象，不占用正式表名和接口编号。

## 1. 当前校验器的实际边界

本轮只读 `ccsop-service/src/super-interface/validator/json-schema-validator.ts`：实现支持 type、required、properties、items、additionalProperties、enum、长度、数值上下界和数组项数；类型声明和实现未提供 pattern、format、uniqueItems、oneOf 或跨字段比较。不能写上 UUID format 就声称服务端已检查 UUID。

只读 `compact-contract-validator.ts`：紧凑契约检查字段类型/必填，请求拒绝多余及 auth/request/userAccount/businessLine/roles/scopes 等可信上下文字段。是否使用紧凑或 JSON Schema 取决于正式元数据注册；本文件不替换当前元数据。

配套 [请求结构草案](contracts/core-request-shapes.json) 仅使用上述 JSON 校验器已支持的结构关键字。该文件是动作到结构的文档映射，不是可直接注册的全局 schema。业务 UUID、重复引用、金额精度、分座容量、归属和状态规则必须由业务层显式校验，不能只依赖结构校验。

## 2. 约束分工

| 层 | 负责内容 | 不能替代 |
|---|---|---|
| 请求结构 | 必填、类型、长度、额外字段拒绝、数组大小 | 不能证明用户有权或业务可执行 |
| 会话与业务 | 主体/门店、来源、配置、状态、金额/数量语义 | 不能靠先查后写避免并发重复 |
| 唯一键/外键 | 永久防重、引用从属、当前对象唯一 | 不能单靠唯一键限制整桌人数或时间重叠 |
| 事务与行锁 | 保护容量、库存、可退额度、终态裁决 | 不能把外部支付纳入本地回滚 |

建议每个业务引用使用 `(tenantRef, storeRef, objectRef)` 约束从属，并让子表引用完整作用域。所有关联查询带作用域，外部商户/店 ID 通过明确映射取得；仅检查 objectRef 存在不够。个人资料与现有会员身份保持引用，不复制建立第二套会员。

## 3. 唯一键与索引候选

| 逻辑对象 | 唯一键/索引候选 | 保护事实 |
|---|---|---|
| CommandRecord | unique(tenantRef, actorRef, action, commandId)；存请求摘要/操作结果 | 同一主体/操作者/动作意图只执行一次；查询结果也校验原操作者或明确管理权限 |
| CurrentRegistration | unique(tenantRef, activityRef, memberRef) | 当前有效报名唯一；失效后退出此当前投影，历史保留 |
| CurrentSeatAssignment | unique(tenantRef, registrationRef)；index(tableSessionRef) | 每个报名仅一个当前分配，换桌保留历史 |
| TableSession | index(tenantRef, storeRef, tableRef, startsAt, endsAt) | 供重叠检查使用，索引本身不保证不重叠 |
| SharedPackageFulfillment | unique(tenantRef, tableSessionRef) | 同次开台只出一份基础套餐 |
| InventoryIssue | unique(tenantRef, storeRef, sourceType, sourceRef, issuePurpose) | 同源同用途出库不重复；退款或补发为独立来源事件 |
| StockBalance | unique(tenantRef, storeRef, locationRef, productRef, batchRef) | 批次/位置余额唯一 |
| AAShare | unique(tenantRef, groupRef, shareIndex) | 份额不重复，金额总和还需事务校验 |
| PaymentFact | unique(channelRef, merchantRef, externalTransactionRef) | 同渠道商户实收事实唯一；同号不同币种/金额不是新付款，应报异常 |
| RefundIntent | unique(tenantRef, paymentRef, refundCauseRef) | 一个确定退款事件只建一次；普通分次退款各有来源且累计受限 |
| WalletEntry | unique(tenantRef, refundRef) | 同一余额退款只入账一次 |
| OutboxEvent | unique(tenantRef, sourceEventRef, eventType)；index(state, nextAttemptAt) | 待办和业务同事务，失败按原事件重试 |

这是候选结构，不是已验证索引。当前投影表避免用 nullable 状态列模拟“只有有效行唯一”；删除当前投影不删除历史。身份证、手机号、券码不作为这些业务唯一键。

## 4. 事务顺序与并发裁决

统一建议顺序：命令去重记录 → 业务根对象 → 库存位置/商品聚合锁 → 批次（稳定 ID 顺序）→ 支付可退额度 → 钱包余额 → 流水/待办。各动作只获取所需对象；所有入口遵循同类对象相同排序。不得在持有数据库锁期间调用外部平台。

### 分座与开台

创建卡座场次先锁卡座配置行，检查其当前有效场次时间范围；所有创建入口都取得同一锁，避免空查询没有锁住任何行。自动/手动分座锁源与目标场次（按 ID 排序），再锁报名（按 ID 排序），核对当前分配、配置版本、男女配比及最大人数。成功才更新当前投影与历史，失败不留下半次换座。

开台锁本次场次，核对状态/配置、已分配有效人数及最小值，随后锁整套商品库存。基础履约唯一键兜底，出库/场次变更/待办同事务。达到最小人数只代表可人工开台，不自动扣库存。

### 库存预留与出库

建议保持每个位置/商品的稳定聚合锁行，即使该商品暂时无批次也可锁定。订单、AA、套餐、调酒、盘点、退库均通过统一库存入口，不能某一入口只改批次跳过聚合约束。批次可用量及预留不能负；整单预留需要所有组成满足，缺一项全部撤销。

预留转换出库时在事务中同时减少在库和相应预留，防止“先释放可售再出库”被其他订单抢走。过期预留仅由相应订单/团状态裁决后释放；不允许定时器忽略已付款状态直接解锁。盘点调整若使实有低于有效预留，转异常处理，不偷偷删除别人的已付权益。

### AA 到期与迟到付款

回调验签/查询渠道后形成可信付款结果，再进入团事务；回调与到期任务均先锁团。只有截止前按既定时间政策可确认、全部份额实付及库存有效才成团。关闭团的迟到实收创建退款意图，不能重新出库。截止前渠道已付但通知迟到的政策在支付适配契约需明确；当前草案按服务端裁决，不以手机时间决定。

到期关闭、释放预留、写已实收退款意图与待办同事务。团状态不允许从 closed 回到 formed；迟到付款可新增退款处理进度，原关闭决策保持。普通资金流水与渠道回调同时进入必须去重。

### APP 余额退款

退款任务先锁退款意图，再锁原支付可退额度、目标主体会员余额，确认目标是原付款人。一次事务写退款流水、增加余额、更新累计已退和成功状态。若在同一核算库无法保证此原子性，则不得上线该方案，须另设计资金状态协议。

余额更新完成但响应丢失：查 refundRef 返回原成功结果，不能再加一次；异常回滚时不得先向会员广播到账。通知在提交后由待办发送，失败只重发通知。跨主体余额通用没有授权，超级管理员也不能通过此动作任意换收款人。

## 5. 逐动作业务校验补充

| 动作 | 结构通过后仍必须检查 |
|---|---|
| JoinActivity | commandId 是有效 UUID；有效本人权益、活动所属店、开放状态、当前报名唯一；不检查某一桌剩余数 |
| ConfirmSeatAllocation | 数组内报名/场次引用不重复，所有目标场次均在版本列表；同一活动和门店；版本、配比、容量在锁内检查 |
| ConfirmSessionOpening | 当前场次、配方版本及库存一致；客户端不得提交 actorRef、任意出库数量或成本 |
| CreateAAGroup | 报价归本人/本店、仍有效；人数份数整数且所有份额正数、总和精确；发起人与份额付款分离；30 分钟由服务端生成 |
| 查询原操作 | 对象作用域及本人/管理权限；commandId 不是访问凭证，不能用猜到的键读取他人资金 |

请求数组候选上限 200、AA 份数候选上限 200 仅为单次请求技术保护，未确认最终业务值；**不限制一个活动的累计报名人数**。更大分座方案可分批原子提交，每批明确成功范围，不把多批宣称为一笔全局事务。

服务端直接拒绝客户端提交 auth、roles、scopes、actorRef、memberRef 等不属于该动作输入的字段。UUID、十进制字符串、时间格式以及安全整数范围需独立检查，不能假设现有 schema 支持这些关键词。

## 6. 验证设计与剩余工作

| 合成场景 | 必须观察的结果 |
|---|---|
| 两请求同时把最后一个名额分给不同会员 | 仅一个成功，无超员、无孤立分配 |
| 两套餐共用最后 4 瓶，各要 4 瓶 | 仅一单获得预留，失败单不占券或部分原料 |
| 两次开台请求使用不同 commandId | 基础履约业务唯一约束仍防止二次出库 |
| 最后 AA 支付与到期同时执行 | 成团或关闭唯一裁决，钱有可追踪去向 |
| 退款成功提交后模拟响应丢失 | 重试原退款不增加第二次余额 |
| 同键修改金额/场次再请求 | IDEMPOTENCY_CONFLICT，原结果不被覆盖 |
| 借他人 commandId 查询 | 拒绝读取，不泄露金额或会员身份 |
| Schema 中错误 UUID 或重复报名引用 | 结构可能通过，业务校验明确拒绝；不得标成结构校验已覆盖 |

上述数据库并发/故障测试尚未执行。本轮只检查文档和 JSON 文件可解析。仍需最终表结构与迁移序列核对、完整请求/响应 schema、锁实现评审、兼容现有紧凑契约的元数据注册方案及隔离测试；不修改当前聊天后端。
