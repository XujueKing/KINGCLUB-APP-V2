# VIP 组局

- Scope ID：`KC-F-024`

- 文档状态：`Draft`
- 所属业务域：`club`
- M0 范围：`In Release Scope`
- 最后更新：2026-08-24

## 目标与用户价值

完成 VIP 组局浏览、创建、邀请和局长管理。

## 本期包含

- [KC-P-030 VIP 组局列表/详情页](pages/page_vip_party_detail/README.md) — `Draft`
- [KC-P-031 VIP 组局创建页](pages/page_vip_party_create/README.md) — `Draft`
- [KC-P-032 局长组局管理页](pages/page_vip_party_management/README.md) — `Draft`

## 本期不包含

聊天群管理不因组局自动纳入本期。

## 待设计内容

- 用户角色、入口、前置条件、主流程和异常流程
- 业务规则、状态机、权限和跨页面导航
- UI 线框/设计版本、全部页面状态和 Mock 场景
- Repository/port、API 或临时 Mock 契约
- 隐私、安全、埋点、测试、灰度与回滚

## 开发门禁

本目录建立只表示进入文档设计队列。功能与所属页面全部达到 `Approved for Development` 前不得开发；本期 48 页全部文档批准前不得创建 Flutter UI，整 App 达到 `UI Flow Approved` 前不得连接真实服务。
