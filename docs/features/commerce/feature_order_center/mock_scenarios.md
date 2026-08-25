# 订单中心 Mock 场景

| ID | 场景 | 预期 |
|---|---|---|
| ORDERS-M01 | 混合类型订单 | 类型和状态清晰 |
| ORDERS-M02 | 全部为空 | 空状态 |
| ORDERS-M03 | 按待支付筛选 | 只显示匹配订单 |
| ORDERS-M04 | 首屏失败 | 可重试 |
| ORDERS-M05 | 下一页失败/重复 | 不重复且可重试 |
| ORDERS-M06 | 下拉刷新状态变化 | 权威替换 |
| ORDERS-M07 | 详情正常 | 金额/历史/动作完整 |
| ORDERS-M08 | OrderRef 无效 | 安全返回 |
| ORDERS-M09 | 非本人订单 | 不泄漏对象是否存在 |
| ORDERS-M10 | 待支付继续支付 | 进入 PaymentIntent |
| ORDERS-M11 | 已确认查看凭证 | 进入 AdmissionRef |
| ORDERS-M12 | 可取消订单 | 二次确认 |
| ORDERS-M13 | 取消冲突 | 重读最新状态 |
| ORDERS-M14 | 取消结果未知 | 原幂等键对账 |
| ORDERS-M15 | 退款中/已退款 | 分开展示 |
| ORDERS-M16 | 未知服务端状态 | 只读+刷新/支持 |
| ORDERS-M17 | 离线缓存列表 | 标记可能过期，不允许写操作 |
| ORDERS-M18 | 会话失效 | 登录 reset |

所有场景只用 Fake；订单状态推送模拟只能触发重新查询。
