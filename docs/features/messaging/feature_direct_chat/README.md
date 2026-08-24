# 稳定单聊

- Scope ID：`KC-F-021`

- 文档状态：`Draft`
- 所属业务域：`messaging`
- M0 范围：`In Release Scope`
- 最后更新：2026-08-24

## 目标与用户价值

提供文本、图片、视频、引用和转发的稳定单聊闭环。

## 本期包含

- [KC-P-024 单聊页](pages/page_direct_chat/README.md) — `Draft`
- [KC-P-025 单聊详情页](pages/page_direct_chat_details/README.md) — `Draft`
- [KC-P-026 联系人选择页](pages/page_contact_selector/README.md) — `Draft`

## 本期不包含

完整群聊、红包和金币转赠本期暂缓。

## 待设计内容

- 用户角色、入口、前置条件、主流程和异常流程
- 业务规则、状态机、权限和跨页面导航
- UI 线框/设计版本、全部页面状态和 Mock 场景
- Repository/port、API 或临时 Mock 契约
- 隐私、安全、埋点、测试、灰度与回滚

## 开发门禁

本目录建立只表示进入文档设计队列。功能与所属页面全部达到 `Approved for Development` 前不得开发；本期 48 页全部文档批准前不得创建 Flutter UI，整 App 达到 `UI Flow Approved` 前不得连接真实服务。
