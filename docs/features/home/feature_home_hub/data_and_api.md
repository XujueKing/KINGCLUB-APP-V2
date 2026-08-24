# 首页数据、Repository 与 Fake 契约

- 文档状态：`In Review`

## 当前建议的 ViewModel

```text
HomeHubViewModel
  greetingName             string?，展示名，不是授权身份
  membershipBadge          verified | member，不展示内部等级分
  venueLabel               string?
  updatedAt                instant
  freshness                fresh | cached | stale
  primaryActions[]         客户端固定四项，服务端只能给 availability/reason
  upcomingJourney?         kind, title, timeLabel, status, opaqueResourceRef
  featuredCards[]          id, imageRef, title, subtitle?, action, accessibilityLabel
  serviceNotice?           stableCategory, title, body, severity, effectiveUntil?
```

## Repository/port

```text
abstract interface HomeHubRepository
  getSnapshot(refreshPolicy) -> HomeHubSnapshot

abstract interface HomeCache
  readEligibleSnapshot() -> CachedHomeHubSnapshot?
  writeSanitizedSnapshot(snapshot)
  clearForSessionChange()
```

- 页面只依赖 Repository，不调用 Dio、超级接口或旧 `interfaceId`。
- 首次进入允许 stale-while-revalidate；缓存必须绑定账号会话世代并设最大展示期限。
- 不缓存二维码、票码、订单金额、Token、手机号或任意运营 HTML。
- 局部模块错误使用稳定 `ModuleErrorCategory`，不透传服务端原文。

## Fake 契约

Fake 必须提供：完整、无行程、无精选、部分失败、全页失败、离线缓存、缓存过期、慢响应、会话切换和未知 `HomeAction`。

## 未来真实接口边界

- 当前未分配或实现 KingClub 首页 K 接口。
- 后续接口应返回首页只读投影，不复刻旧接口把 Tab、版本更新、完整用户资料、钱包和内容流塞进同一响应。
- 服务端可控制业务入口的 `available/reasonCategory`，不能控制入口顺序、图标、目标路由或任意文案动作。
- `opaqueResourceRef` 只能交给对应页面/Repository 再做对象级权限校验；首页缓存不赋予业务权限。
