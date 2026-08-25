# 支付安全页状态

`loading/statusNotSet/statusSet/locked/verifyingOld/beginningSms/verifyingSms/enteringNew/confirmingNew/submitting/succeeded/resultUnknown/error/sessionInvalid`

- 锁定与剩余时间只服从服务端。
- 输入不匹配留在确认步骤，不提交。
- 结果未知隐藏输入并用原幂等键对账。
