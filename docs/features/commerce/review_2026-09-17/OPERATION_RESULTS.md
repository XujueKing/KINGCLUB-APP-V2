# 操作结果查询与非成功响应

2026-09-18，In Review。统一 [成功结果](contracts/core-response-shapes.json) 之外的处理中、拒绝和结果查询。结构草案见 [非成功响应](contracts/operation-result-shapes.json)，均是业务体，尚未注册真实接口。

## 1. 命令执行与业务状态分开

- outcome=succeeded：这次命令已提交，不代表关联订单已交付或所有退款完成。创建 AA 成功时 groupState 仍 collecting。
- outcome=processing：已接收并有 operationRef，结果未完成或外部事实未知；只查询原命令，不重新支付。
- outcome=rejected：本次命令明确未生效。错误码描述原因，重新操作前需读取最新事实。同 commandId 重试保留原拒绝结果；用户确认新报价/新版本后才是新意图。
- 找不到操作：查询返回 found=false，不能当作 rejected，更不能据此断言没有付款。客户端可按协议重试同 commandId；服务端必须先凭命令与原支付尝试唯一约束裁决，禁止生成另一笔外部支付。

鉴权失败、解密失败或请求格式不合法可能尚无有效 commandId，由现有传输/错误处理层返回；不要硬造业务操作回执。这类错误也不意味着原先发出的另一请求未执行。

## 2. 查询范围和字段

GetCommandOutcome params：storeRef、action、commandId。服务端从会话确定主体和实际操作者；action 必须来自已注册可查询动作白名单。管理员查看别人的操作用独立业务对象查询权限，不直接冒用 actorRef。

found=true 必须返回 commandId、operationRef、action、outcome、queriedAt；succeeded 关联原结果，processing 返回 retryAction=query_original，rejected 返回原错误。命令结果使用首次确认快照，currentObjectVersion 可另行提示，页面不得把旧结果覆盖较新对象。

QueryFound 的条件校验：succeeded 必须有 originalResult 且按对应动作成功结构验证；processing 必须有 retryAction，不能携带最终成功 originalResult；rejected 必须有 error，不携带成功结果。结构文件只表达公共字段和可选分支字段，这些互斥/必填关系必须额外实现，尚未经过服务端验证。

found=false 返回 found、commandId、action、queriedAt、retryAction=query_or_retry_same_command。此值仅说明当前授权查询未见记录；访问不存在与无权对象的响应不得泄露其他主体存在性。

时间与 UUID 格式、响应条件字段和动作一致性仍需业务校验，现有结构校验器不支持所有 Schema 分支表达。文件中的每个结构单独验证，不能把文件整体当单个 schema 注册。

## 3. 拒绝后的页面动作

| 错误 | 用户可见反馈 | 后续行为 |
|---|---|---|
| VERSION_CONFLICT | 数据已更新，请核对变化 | 查询新版本，用户确认后新意图 |
| STOCK_INSUFFICIENT | 列出缺货商品 | 重报价格/数量，不自动换酒 |
| CAPACITY_CONFLICT | 当前卡座人数或配比不满足 | 返回分座，原有效分配不丢失 |
| IDEMPOTENCY_CONFLICT | 同一操作提交了不同内容 | 查原意图，不覆盖原命令 |
| COUPON_IN_USE | 券在另一付款处理中 | 查看本人原单，不凭手机超时解锁 |
| POLICY_MISSING | 此操作规则尚未配置 | 回来源或管理员配置，不猜退款去向 |

业务错误不把 SQL、堆栈、密钥或其他会员标识直接给客户端。reasonKey 用四语言资源解释；fieldErrors 用稳定字段路径定位。通知失败不把已成功命令改成 rejected。

## 4. 本轮同步与剩余工作

已把当前页面和核心流程的业务 requestId 改为 commandId，并修正 AA 单状态旧示例。服务端原始证据中的 requestId 保留，因为它确实是传输上下文现有字段。

入口 README 合并连续进度追加为当前评审导航；历史提交仍在 Git，不再要求读者从多条累计页数中判断最新状态。

仍缺所有动作的完整响应/错误分支、可执行 Schema 契约测试、实际 DTO 映射和正式接口注册；数据库并发/故障恢复未测试，不把文档自检当服务验收。
