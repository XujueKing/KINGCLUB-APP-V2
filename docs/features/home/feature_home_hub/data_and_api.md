# 首页数据、Repository 与 Fake 契约

- 文档状态：`In Review`
- 设计版本：`Legacy Home Component Content v1`

## 当前建议的 ViewModel

```text
LegacyHomeViewModel
  memberHeader
    displayName
    genderPresentation        male | female | unspecified
    levelName
    expValue
    verified
    goldCoinNumber
    diamondNumber
    progressPercent
  banners[]
    id, bannerImageRef, contentBlocks[], accessibilityLabel
  quickActions[]              客户端固定三项
    togetherPlay | exclusiveSeats | scanQr
  promotions[]
    id, mode, imageRef, title?, authorAvatarRef?, authorName?, visits?
    contentBlocks[], accessibilityLabel
  navigationBadges
    messagesUnread
  updatedAt
  freshness                    fresh | cached | stale
```

完整组件字段与视觉内容见 [首页组件内容复刻总表](pages/page_home/components/README.md)。

## Repository/port

```text
abstract interface HomeHubRepository
  getSnapshot(refreshPolicy) -> LegacyHomeSnapshot

abstract interface HomeCache
  readEligibleSnapshot() -> CachedLegacyHomeSnapshot?
  writeSanitizedSnapshot(snapshot)
  clearForSessionChange()
```

- 页面只依赖 Repository，不调用 Dio、超级接口或旧 `interfaceId`。
- 当前 UI 阶段只提供 `FakeHomeHubRepository`，首屏快照固定，保证截图可重复比较。
- 缓存必须绑定账号会话世代；不缓存二维码、票码、Token、手机号、实名、任意运营 HTML 或脚本。
- 图片内艺术字属于图片资产；ViewModel 不重复携带用于覆盖图片的同名展示文本。
- 局部模块错误使用稳定 `ModuleErrorCategory`，不透传服务端原文。

## 动作白名单

```text
HomeAction
  openAaReservations
  openVipParty
  openSafeScanner
  openCampaignPreview(campaignId)
  openPromotionPreview(promotionId)
```

未知、过期或未批准动作失败关闭。不得把接口返回的 URL、路由名或整对象直接用于导航。

## 旧接口审计事实

旧首页超级接口 `S231202503100658` 同时返回会员展示、资产、`adData`、`nat_list`、`tabData`、版本信息和客户端配置。该响应只用于理解旧 UI，不作为 V2 接口形状。

旧内容字段包括：

- 头部：`userNick`、`gender`、`levelName`、`vipLevel`、`isVerify`、`goldCoinNumber`、`diamondNumber`、`percent`；
- Banner：`bannerImg`、JSON `content`；
- 内容卡：`mode`、`src`、`title`、`userImg`、`userNick`、`visits`、URL 编码 JSON `content`；
- 底栏：`id`、`src`、`src_choose`、`dot`、`num`。

## 未来真实接口边界

- 当前未分配或实现 KingClub 首页 K 接口。
- 后续接口应返回清洗后的首页只读投影，不复刻旧接口的多域大包。
- 会员头部展示值来自共享身份/会员/资产域的聚合投影，但不能作为权限依据。
- 服务端可以下发运营内容和可用性，不能控制三个核心入口顺序、五个底栏目的地或任意客户端路由。
- Banner/内容详情必须转换为类型化内容块，不允许 App 执行服务端 HTML/JS。
