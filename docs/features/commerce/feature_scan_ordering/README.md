# 扫码点单

- Scope ID：`KC-F-027`

- 文档状态：`Draft`
- 所属业务域：`commerce`
- M0 范围：`In Release Scope`
- 最后更新：2026-08-24

## 目标与用户价值

从批准桌码进入商品选择、购物车和点单确认。

## 本期包含

- [KC-P-034 扫码点单商品/购物车页](pages/page_scan_ordering_cart/README.md) — `Draft`
- [KC-P-035 点单确认页](pages/page_scan_order_confirmation/README.md) — `Draft`

## 本期不包含

不信任二维码或客户端携带的价格。

## 待设计内容

- 用户角色、入口、前置条件、主流程和异常流程
- 业务规则、状态机、权限和跨页面导航
- UI 线框/设计版本、全部页面状态和 Mock 场景
- Repository/port、API 或临时 Mock 契约
- 隐私、安全、埋点、测试、灰度与回滚

## 开发门禁

本目录建立只表示进入文档设计队列。功能与所属页面全部达到 `Approved for Development` 前不得开发；本期 48 页全部文档批准前不得创建 Flutter UI，整 App 达到 `UI Flow Approved` 前不得连接真实服务。
