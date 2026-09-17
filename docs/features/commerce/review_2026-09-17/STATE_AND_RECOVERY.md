# 响应、状态转换与异常恢复 v0.1

2026-09-18，In Review，仅文档。承接 [核心契约](CORE_DATA_CONTRACTS.md) 与 [约束设计](DATABASE_AND_VALIDATION.md)。本轮细化的是业务结果体，不改现有 CCSOP 加密/HTTP 包装。

## 1. 响应统一

成功命令返回 commandId、operationRef、objectRef、version、outcome、result；outcome 为 succeeded 或 processing。查询必须区分操作结果与当前对象状态：重复命令读取首次结果，另查对象取得最新版本，不能用旧回执覆盖新页面。异常返回 error.code、reasonKey、fieldErrors、retryAction 及可安全展示的对象引用，不能泄露他人数据。

结构样例见 [成功响应结构](contracts/core-response-shapes.json)。它只约束成功结果，processing/error 必须由独立响应变体处理；现有校验器不支持 oneOf，正式注册时需明确选择分支，不能将成功结构强套在失败响应上。动作语义名不是正式 interfaceId。

查询接口草案：GetCommandOutcome 输入 action、commandId、storeRef；服务端校验原操作者/管理权限后返回 found、operationRef、outcome、objectRef。found=false 仅指当前未找到记录，不证明外部无付款或另一个事务未提交；不得因此换键再次支付。

## 2. 修正 AA 状态的歧义

此前把 collecting/forming/formed/closing/refunding/closed 写在一个状态字段，无法清楚表达“已关闭之后又收到迟到付款”。本轮建议拆成两个事实：

- groupState：collecting → formed 或 closed。formed/closed 是互斥的组团裁决；事务中的 forming/closing 不作为持久业务终态。
- refundState：not_required、pending、processing、completed、attention_required。由退款明细汇总，迟到实收可以把 completed 再变为 pending，但 **groupState 始终 closed，不重新成团**。

“退款全部完成”只表示截至 queriedAt 已确认实收对应的退款都已入账，不保证渠道未来没有迟到结果。页面显示“未成团，退款处理中/已退 APP 余额”，不得误报新的成团。

旧页面的 refunding/closed 作为显示语义映射到新双状态；正式 DTO 和全部旧样例需在冻结时统一，本文件优先于旧单字段方案，不宣称当前服务已经采用。

## 3. 状态转换表

| 对象/当前状态 | 触发与条件 | 下一状态 | 同事务效果 |
|---|---|---|---|
| 报名待分配 | 受控分座符合版本/容量/配比 | 已分配 | 写当前分配及历史 |
| 报名已分配 | 本人实际到店，由管理员确认 | 已入座 | 写实际入座时间，不重复套餐出库 |
| 未分座报名 | 管理员决定失效/退票 | 人工失效 | 记录原因；退票单独进度，不套 AA 期限 |
| 卡座待开台 | 人数满足且整桌商品足够，员工确认备酒 | 营业中 | 场次、套餐履约、批次出库、待办一次提交 |
| AA collecting | 截止前裁决且所有份额款项齐、预留有效 | formed | 唯一销售订单与整单出库 |
| AA collecting | 到期未满足成团条件 | closed | 释放预留，按已实收创建退款意图 |
| AA closed | 新确认迟到实收 | closed | 去重付款事实，新增退款意图；refundState 更新 |
| 退款 pending/processing | 原付款额度合法、余额流水原子成功 | succeeded | 加原付款会员对应主体余额一次 |
| 退款 processing | 不可自动修复异常 | attention_required | 保留金额和原因，不记假到账 |
| 预留 active | 原订单/团成功裁决 | consumed | 同事务扣实物及预留、生成出库 |
| 预留 active | 原订单/团关闭裁决 | released | 仅释放，不伪造采购入库 |

成团截止时间仍按服务端裁决的当前建议执行；是否接受截止前渠道已付但迟到通知仍需支付适配政策定稿，不能由客户端时间决定。退款成功后不改回 pending 重付；迟到新付款产生另一退款意图。

## 4. 故障恢复矩阵

| 故障位置 | 查什么 | 恢复动作 | 禁止行为 |
|---|---|---|---|
| 提交后断网 | 原 commandId 操作记录及对象版本 | 同意图查结果，确认可重试时用原键 | 换键重开台或重付 |
| 内部事务死锁/回滚 | 事务结果与命令记录 | 有界重试，重新读取同一业务意图 | 改价格/人数后复用原键 |
| 付款渠道超时 | 原支付尝试和渠道交易事实 | 查询/对账，展示未知 | 直接认失败并再次收款 |
| AA 到期任务宕机 | 到期 collecting 团扫描索引 | 恢复后锁团补裁决，客户端禁止过期付款入口 | 延长 30 分钟或永远锁库存 |
| 余额写成功、响应丢失 | refundRef 唯一流水 | 返回原成功 | 再加余额或原路退一次 |
| 出库成功、通知失败 | 已出库单及待办 | 只重发通知，查询可展示待备 | 撤销成功出库后重新扣 |
| 退款部分成功 | 各退款意图及各会员余额流水 | 只重试未成功项，汇总展示进度 | 整团退款重跑全部加钱 |
| 分座成功、手机旧缓存 | 原分配版本与当前桌台 | 拉取最新，不覆盖历史 | 再生成同一人的第二席位 |

任务恢复建议带执行租约、尝试次数、下次执行时点，租约超时可被其他工作者接手；正确性仍由事务和业务唯一约束保证，不依赖“任务只跑一次”。重试上限转人工待办，不能抛弃已收款或隐藏差额。具体调度间隔/超时值按运行条件定稿。

## 5. 锁顺序与幂等审阅结论

- 业务 commandId 与传输 requestId 分开，基础约定正文同步修正，避免只有顶部声明而字段表仍矛盾。
- 命令查询权限必须核验，键本身不是取数据凭证；支付回调和定时任务使用可追踪内部身份，业务唯一键仍防止跨入口重复动作。
- 退款工作者只处理独立退款意图及支付额度、钱包，不在持有钱包锁后反向获取团/库存锁。团关闭仅创建退款意图，避免与工作者反向锁顺序。
- 分座/开台/库存动作锁同类对象按 ID 排序；日志或通知不能在提交前发布成功。必须以真实并发测试确认，本文仅设计审阅。

## 6. 合成响应与验收

```json
{"groupRef":"demo-aa","groupState":"closed","refundState":"completed","queriedAt":"2026-09-18T12:31:00Z","knownPaidMinor":20000,"refundedMinor":20000,"currency":"CNY"}
```

迟到的第三笔实收确认后：

```json
{"groupRef":"demo-aa","groupState":"closed","refundState":"pending","queriedAt":"2026-09-18T12:32:00Z","knownPaidMinor":30000,"refundedMinor":20000,"currency":"CNY"}
```

后续验收须断言：团始终 closed、无销售出库、前两笔退款不再入账、第三笔到账后退款合计 30000。另需覆盖过期任务恢复、退款租约重领、错误响应不满足成功结构时不伪装成功、重复旧回执不覆盖新版状态。

本轮只验证 JSON 可解析及文档链接，未执行数据库/接口/故障注入测试。响应变体、全动作 DTO、数据库迁移、性能及恢复指标仍待定稿。
