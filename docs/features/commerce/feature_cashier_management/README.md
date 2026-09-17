# 收银管理：重新设计评审

状态：In Review，未批准业务开发。

手机与吧台看板展示预定、入座、消费、AA 进度、备酒任务、交班、备用金和小票；终端绑定门店，员工操作留痕。

- [总体需求](../review_2026-09-17/REQUIREMENTS.md)
- [平台与多门店](../review_2026-09-17/PLATFORM_AND_STORES.md)
- [AA 与共享套餐](../review_2026-09-17/AA_AND_SHARED_PACKAGE.md)
- [手机与收银机](../review_2026-09-17/MOBILE_AND_COUNTER.md)
- [架构](../review_2026-09-17/ARCHITECTURE.md)、[数据设计](../review_2026-09-17/DATA_DESIGN.md)
- [旧系统审计](../review_2026-09-17/LEGACY_AUDIT.md)、[验收条件](../review_2026-09-17/ACCEPTANCE.md)
- [数据库评审](database_review.md)

界面以非专业员工能完成任务为准；跨店权限、金额、库存和状态由服务端校验。更正保留来源，不覆盖历史。具体页面字段、错误状态、接口契约和逐页验收仍需在业务规则评审后补齐。本文件不覆盖旧版已批准文档状态，也不代表新设计已获批准。
