# 私人储物柜旧版审计

- 文档状态：`Approved for Development`
- 基线：`KingClub-app / master / 505d222`

| 旧行为 | 风险 | V2 |
|---|---|---|
| URL 传 selectBox JSON | 可篡改/陈旧 | 只传 StorageItemRef |
| 静态 URL 二维码 | 截图与重放 | 短时动态 token |
| 显示 storedId/库位/员工 | 过度披露 | 最小消费者投影 |
| 2 秒轮询 | 流量、并发和错误成功 | 受控事件提示+权威查询 |
| 员工 getWine | 角色混入 | 移出消费者 App |
