# 一起玩 AA 预订页

- Scope ID：`KC-P-027`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[一起玩 AA 预订](../../README.md)
- 旧版来源：`Choose`
- 路由：`AaReservationsRoute`，`/club/aa`
- 设计版本：`AA Reservation Wireframe v1 / Landing`
- 最后更新：2026-08-25

## 用户任务与线框

选择营业日，查看已有 AA 预订和可订套餐，并安全进入套餐详情。

```text
[返回]                一起玩 AA
[今天 08.25] [周三 08.26] [周四 08.27] ...

[已有预订]
 待支付 · 还剩 09:42                     [继续]
 或 已确认 · 8月25日 20:30               [查看]

[规则摘要] 一人一席 · 系统分桌 · 以确认页报价为准

[系统推荐套餐]                              [查看]
 卡座区域 / 套餐名       ¥价格起 / 人       少量

[其他可订套餐]
 套餐卡片 ...

                    [没有合适的？刷新]
```

- 日期使用服务端 `ServiceDay`，不在 UI 硬编码 14 天或营业时段。
- 已有有效预订优先展示；同一营业日有待支付/已确认预订时禁用新订入口。
- 套餐卡只显示匿名容量、价格、规则摘要和模糊余量，不展示同桌人员信息。
- 空态区分未开售、已截止、无场次、全部售罄和功能维护。
- 200% 字体下日期条可横向滚动，卡片纵向扩展；价格和状态具备读屏标签。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
