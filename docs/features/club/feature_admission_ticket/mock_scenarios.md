# 入场凭证 Mock/Fake 场景

| ID | 场景 |
|---|---|
| TICKET-M01 | 已确认订单但未到凭证开放时间 |
| TICKET-M02 | readyToEnter 动态码签发与按策略轮换 |
| TICKET-M03 | token 刷新暂时失败，旧码到期后遮盖 |
| TICKET-M04 | 工作人员核验事件到达后权威重读 checkedIn |
| TICKET-M05 | 重复扫描返回 alreadyCheckedIn |
| TICKET-M06 | 已入场状态、入场时间和离场说明 |
| TICKET-M07 | 有效场内 admissionContext + 用户确认离场 |
| TICKET-M08 | 离场连点/超时，以同一幂等键对账 |
| TICKET-M09 | checkedOut 且允许再次入场，签发新版本码 |
| TICKET-M10 | checkedOut 不允许再次入场或活动已结束 |
| TICKET-M11 | 订单取消/退款后 credentialVersion 撤销旧码 |
| TICKET-M12 | 风控 suspended 与工作人员协助 |
| TICKET-M13 | 非本人 AdmissionRef、无权限或引用过期 |
| TICKET-M14 | admissionContext 过期、错误场所或错误用途 |
| TICKET-M15 | 离线进入/断网，不生成长期备用码 |
| TICKET-M16 | App 后台/任务切换遮盖并销毁 token |
| TICKET-M17 | 录屏/投屏检测后的安全提示与遮盖 |
| TICKET-M18 | 会话失效、切换账号和旧 generation 响应 |
| TICKET-M19 | 未知服务端状态只读降级 |
| TICKET-M20 | 大字体、读屏、低亮度和二维码高对比度 |
