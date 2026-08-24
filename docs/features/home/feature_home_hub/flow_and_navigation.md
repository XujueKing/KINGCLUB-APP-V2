# 首页流程与导航

- 文档状态：`In Review`

## 前置条件

- `authenticated=true`
- `membershipStatus=approved`
- App Shell 已建立，当前分支为 `home`

不满足时由全局守卫 reset 到登录或会员准入权威页，首页不自行修正身份状态。

## 主流程

```text
进入/恢复 HomeRoute
  -> 立即显示骨架或合格缓存
  -> FakeHomeHubRepository.getSnapshot()
      -> ready：渲染入口、行程、精选和服务提示
      -> partial：保留可用模块，失败模块内联重试
      -> empty：保留核心入口，显示无行程/无精选
      -> fatal：保留 Shell，显示全页重试
```

## 导航动作

| 动作 | RouteIntent | 规则 |
|---|---|---|
| 一起玩 AA | `openAaReservations` | 页面批准前只保留 Fake 意图 |
| VIP 组局 | `openVipParty` | 进入列表/详情语义，具体页批准后激活 |
| 入场凭证 | `openAdmissionTicket` | 不在首页生成或核销凭证 |
| 安全扫码 | `openSafeScanner(origin=home)` | 与 Shell 中央扫码同一状态机 |
| 精选活动 | `executeHomeAction(action)` | 仅客户端枚举 allowlist |
| 重选首页 Tab | `PrimaryDestinationReselected` | 滚动到顶，不隐式刷新 |

## 返回和生命周期

- HomeRoute 是首页分支根；Android 返回交给 Shell 的系统后台/退出语义。
- 从子页返回时恢复首页滚动位置和最后成功快照，必要时根据失效标记刷新单个摘要。
- 进程终止不持久化滚动位置；重新鉴权后回首页顶部。
- `sessionGeneration` 改变时丢弃旧快照响应并由全局流程 reset。

## 当前建议的 `HomeAction`

```text
none
openAaReservations
openVipParty
openAdmissionTicket
openSafeScanner
selectPrimaryDestination(discover | me)
```

未知、过期或当前版本未批准的动作显示“此内容暂不可用”，不得回退为动态 URL。
