# 日志与可观测性

- Scope ID：`KC-F-006`

- 文档状态：`Approved for Development`
- 优先级：P0
- 当前建议：先定义供应商中立端口，后续再选择崩溃/性能平台

## 目标

提供可定位启动、网络、登录、会话、导航和后续业务问题的结构化证据，同时确保手机号、验证码、身份资料、聊天内容和凭据不会进入日志、埋点或崩溃附件。

## 三类信号

| 信号 | 用途 | 默认策略 |
|---|---|---|
| operational log | 本地/服务端故障定位 | 结构化、分级、开发可见，生产采样 |
| crash/performance | 崩溃、ANR、启动和慢请求 | 供应商 adapter，严格附件白名单 |
| product analytics | 页面/漏斗/功能使用 | 与运营及隐私同意单独评审，不自动启用 |

## 事件最小结构

```text
eventName
eventVersion
timestamp
environment
appVersion/buildNumber
platform/osVersion
runId
requestId/traceId (如适用)
resultCategory
durationBucket
approved attributes
```

- 默认拒绝字段，只有 schema allowlist 能上报；禁止“把整个对象转 JSON”。
- 禁止手机号及其哈希、验证码、challenge、Token、API Key、证件、人脸、聊天正文、订单支付响应全文和协议正文。
- `userAccount` 默认不发往第三方；如未来业务确需关联，使用独立、可轮换、供应商专用的匿名标识并完成隐私评审。
- requestId/traceId 用于客户端与服务端关联，展示和上传前仍要校验格式与长度。

## 生命周期与失败

- 全局错误捕获在读取会话前安装；捕获器自身失败不能导致 App 崩溃循环。
- 离线事件使用有界队列、TTL 和容量上限；高敏事件不落普通磁盘队列。
- 环境、版本和采样策略由 bootstrap 注入，业务 feature 不直接初始化厂商 SDK。
- 用户注销、撤回可选分析同意或切换环境时，清理相应本地队列与供应商上下文。

## 配套文档

- [验收标准](acceptance.md)
- [Foundation 索引](../README.md)

## UI/Mock 阶段边界

- UI 阶段只实现内存/控制台型 `FakeOperationalLogger` 与测试探针；不得初始化第三方崩溃、性能或产品分析 SDK。
- Mock 事件只能使用纯虚构数据和 allowlist 字段，并支持测试中断言“禁止字段从未出现”。
- 厂商选择、隐私同意、采样、上传和生产数据保留期在 `UI Flow Approved` 后独立评审。

## 交付状态

- **已确认事实**：operational、crash/performance 与 product analytics 使用独立端口和独立启用策略。
- **已确认事实**：用户于 2026-08-26 同意供应商中立、默认拒绝字段、UI 阶段不启用第三方 SDK的方案。
- **待真实接入验证**：供应商 SDK、隐私文本、采样率、上传失败与生产保留策略不属于当前文档/UI 门禁。
