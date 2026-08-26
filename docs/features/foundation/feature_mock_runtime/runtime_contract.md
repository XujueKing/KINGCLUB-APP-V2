# Mock Runtime 运行时与注入契约

## 组成

```text
ScenarioManifest
  -> ScenarioRuntime
       -> VirtualClock
       -> FakeDataStore
       -> ScriptedEventBus
       -> FailureController
       -> FakePortRegistry
            -> FakeSession / FakeSuperInterface / FakeRealtime
            -> FakePayment / FakePermission / FakeScanner
            -> FakeMedia / FakeNotification / FakeLifecycle
```

## ScenarioManifest

最小字段：`scenarioId`、`version`、`seed`、`initialRouteIntent`、`initialSessionState`、`clockStart`、`fixtures`、`scheduledEvents`、`failureRules`、`expectedCheckpoints`。

- `scenarioId` 使用稳定命名，例如 `auth.sms.timeout`、`order.payment.unknown`。
- Manifest 只引用纯虚构 fixture，不嵌入手机号、证件、Token 或生产 ID。
- 未识别版本失败关闭到安全的 Mock 选择状态，不静默使用默认成功场景。

## 时间、事件与并发

- 业务倒计时、凭证轮换、会话过期、消息送达和支付回查使用 `Clock` 端口，不直接读取系统时间。
- `advanceBy/advanceTo` 原子推进虚拟时间；同一时间事件按 manifest 序号稳定排序。
- 延迟返回携带 runtime generation；切换/重置场景后，上一 generation 的结果必须丢弃。
- 可脚本化重复点击、乱序事件、重复事件、结果未知、前后台和进程重建。

## 数据与重置

- 每个场景创建独立数据集；列表 cursor、订单、会话、未读、资产和储物状态可以变更，但不得跨场景泄漏。
- `softReset` 回到当前 manifest 初始快照；`hardReset` 同时清空场景选择、缓存和事件队列。
- 所有 Fake 写操作仍执行批准的幂等、所有权和状态机规则，不能为了演示而直接跳到成功页。

## 端口注入

- App/feature 只依赖自有端口；Mock flavor 在唯一组合根统一 override。
- 禁止 Widget 内出现 `if (mock)`、手写延迟或直接读取 fixture。
- 每个 Fake 方法支持成功、稳定业务错误、传输错误、取消、超时和结果未知中的适用集合。
- 未注册端口必须立即报开发错误，不能回落到真实网络。
