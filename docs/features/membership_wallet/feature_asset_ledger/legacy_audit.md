# 钱包与流水旧版审计

- 文档状态：`Approved for Development`
- 审计基线：`KingClub-app / master / 505d222 / 1.1.37`

| 旧实现 | 发现 | V2 处理 |
|---|---|---|
| `mybalance` 四 tab | 订单和三种资产混为账单 | 订单迁订单中心；资产按单位筛选 |
| 请求 userAccount | 本地账号决定查询对象 | 当前会话决定本人资产 |
| `log_list` JSON 字符串 | 无类型契约，字段 A/B/C/T | 显式 AssetSummary/LedgerEntry DTO |
| pageNum 合并 | 易重复、错序、刷新污染 | 稳定 cursor + entryRef 去重 |
| 客户端汇总文案 | 收入/支出可能与余额口径混淆 | 服务端返回摘要与 asOf |
| 点击订单项 | 传 id/type 到旧详情 | 只接受服务端 OrderRef |
| 旧提现/转赠 | 混有代理和聊天资产写入 | M0 明确排除 |

旧 A/B/C 等展示字段和接口编号不进入 V2 领域模型。
