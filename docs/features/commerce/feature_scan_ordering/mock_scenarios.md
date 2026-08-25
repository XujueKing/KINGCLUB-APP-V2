# 扫码点单 Mock 场景

| ID | 场景 | 预期 |
|---|---|---|
| ORDERING-M01 | 有效桌码与正常目录 | 可浏览并加购 |
| ORDERING-M02 | 桌码无效/过期 | 安全错误并返回扫码 |
| ORDERING-M03 | 非本场次桌码 | 禁止点单 |
| ORDERING-M04 | 门店暂停营业 | 只读说明 |
| ORDERING-M05 | 目录加载失败 | 可重试 |
| ORDERING-M06 | 空目录 | 空状态 |
| ORDERING-M07 | 商品售罄 | 禁止加购 |
| ORDERING-M08 | 达到限购 | 数量不再增加并说明 |
| ORDERING-M09 | 本地草稿恢复 | 仅恢复商品选择 |
| ORDERING-M10 | 草稿商品已失效 | 标出并移除失效项 |
| ORDERING-M11 | 正常报价 | 展示服务端明细 |
| ORDERING-M12 | 价格上涨/下降 | 展示差异并要求确认 |
| ORDERING-M13 | 库存不足 | 定位问题项 |
| ORDERING-M14 | 优惠失效 | 重报价并说明 |
| ORDERING-M15 | QuoteRef 过期 | 禁止下单并刷新 |
| ORDERING-M16 | 正常创建订单 | 进入支付处理 |
| ORDERING-M17 | 双击提交 | 只创建一单 |
| ORDERING-M18 | 创建超时结果未知 | 原幂等键对账 |
| ORDERING-M19 | 离线 | 不创建订单，保留安全草稿 |
| ORDERING-M20 | 会话失效 | 清理敏感引用并登录 reset |

所有场景只用 Fake，不调用真实商品、库存、订单或支付服务。
