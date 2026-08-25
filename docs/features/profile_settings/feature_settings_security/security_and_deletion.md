# 安全与注销规则

## 支付 PIN

- 6 位数字、禁止全相同/简单连续组合；具体失败次数和锁定期由服务端策略返回。
- 修改需旧 PIN；忘记/首次设置走短信重新认证，同一 challenge 不可重放。
- 输入框禁止复制、粘贴、自动填充、截图日志和明文持久化。
- 超时/结果未知使用原幂等键查询，不重复设置。

## KingClub 注销

`preflight -> blockers | eligible -> reauthenticate -> finalConfirm -> submitting -> completed | resultUnknown`

- blockers 至少覆盖未结订单、支付/退款/申诉、可用或冻结资产、未取私人储物、进行中组局。
- 注销对象是 KingClub app membership/profile；共享 person/account、物业 membership 与法定留存数据不随之删除。
- 成功后撤销所有 KingClub session/WebSocket/push 绑定，清理本地数据并 reset 到登录。
- 服务端返回数据删除/匿名化与依法留存摘要；客户端不得承诺立即物理清除全部备份。
