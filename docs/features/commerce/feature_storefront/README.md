# 商店：重新设计评审

状态：In Review，未批准业务开发。

2026-10-28 用户要求先设计每个特约商户独立的店铺主页，承接活动卡LOGO并串联找店、活动与订位。最新方案见[店铺主页设计](2026-10-28-store-home/DESIGN.md)与[交互预览](2026-10-28-store-home/preview.html)。本轮仅设计评审，未修改正式APP、接口或数据库；下方商品商城/配送/链上订单属于另一组历史评审范围。

详细草案：[商品、自提、配送与链上订单](../review_2026-09-17/FINANCE_AND_STORE_CONTRACTS.md)、[页面衔接和权限](../review_2026-09-17/ROLES_AND_PAGE_MAP.md)。

地区和门店选择、到店商品、配送/自提、链上商品；发行方、适用门店与收款主体明确。

- [总体需求](../review_2026-09-17/REQUIREMENTS.md)
- [平台与多门店](../review_2026-09-17/PLATFORM_AND_STORES.md)
- [AA 与共享套餐](../review_2026-09-17/AA_AND_SHARED_PACKAGE.md)
- [手机与收银机](../review_2026-09-17/MOBILE_AND_COUNTER.md)
- [架构](../review_2026-09-17/ARCHITECTURE.md)、[数据设计](../review_2026-09-17/DATA_DESIGN.md)
- [旧系统审计](../review_2026-09-17/LEGACY_AUDIT.md)、[验收条件](../review_2026-09-17/ACCEPTANCE.md)
- [数据库评审](database_review.md)

界面以非专业员工能完成任务为准；跨店权限、金额、库存和状态由服务端校验。更正保留来源，不覆盖历史。具体页面字段、错误状态、接口契约和逐页验收仍需在业务规则评审后补齐。本文件不覆盖旧版已批准文档状态，也不代表新设计已获批准。
