# Mock 场景与 Fake Runtime

- Scope ID：`KC-F-008`
- 文档状态：`Draft`
- 所属业务域：`foundation`
- M0 范围：`In Release Scope`
- 最后更新：2026-08-24

## 目标与用户价值

定义可离线复现整 App 主流程、异常流程和返回路径的 Fake Repository、虚拟时钟、场景切换和测试数据边界。

## 页面清单

本功能不拥有页面；它为 48 页提供批准的 Mock/Fake 场景。

## 待设计内容

- 场景编号、数据隔离、虚拟时间、随机性和重置规则
- Fake Session、Fake WebSocket、Fake 支付/推送/权限/扫码事件
- 个人信息、订单、聊天和资产的纯虚构数据规范
- 演示入口、自动化测试注入和禁止真实网络的防护

## 开发门禁

当前只允许文档设计。全部功能/页面文档批准后才能实现 Fake Runtime；`UI Flow Approved` 前不得加入真实 adapter。

