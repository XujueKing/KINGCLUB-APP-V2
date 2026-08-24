# 个人中心流程与导航

- 文档状态：`Approved for Development`

## 前置条件

- `authenticated=true`
- `membershipStatus=approved`
- App Shell 已建立 me 分支

不满足时由全局守卫 reset 到登录或会员准入权威页。

## 主流程

```text
MyProfileRoute
  -> getMyProfileSnapshot()
  -> 编辑资料 -> EditProfileRoute
       -> 保存成功 pop(ProfileUpdateResult)
       -> 我的主页按 profileVersion 合并/刷新
  -> 个人二维码 -> PersonalQrRoute
       -> getFriendInvite()
       -> 过期前刷新 / 返回
  -> 订单、资产、储物柜、设置 -> 对应批准 RouteIntent
```

## 类型化导航

```text
openEditProfile
openPersonalQr
openOrderCenter
openAssetLedger
openPrivateStorage
openSettings
back
```

- MyProfileRoute 是 me 分支根，location 为 `/me`。
- EditProfileRoute 建议为 `/me/edit`，无 URI 参数；草稿只在页面内存中。
- PersonalQrRoute 建议为 `/me/qr`，无 URI 参数；token 不进入 location、query 或恢复状态。
- 下游页面尚未批准时只使用 Fake RouteIntent，不建立占位 Flutter 页面。

## 返回与生命周期

- 重按“我的”Tab：子页 pop 到 MyProfileRoute；已在根页则滚动到顶，不自动请求。
- 编辑页有未保存变更时返回先确认“放弃修改”；上传/保存中按状态机处理。
- 二维码页返回立即销毁 token 和画面模型；切后台时遮挡二维码，回前台重新检查有效期。
- session generation 改变时清理资料缓存、编辑草稿、媒体引用和邀请 token，并由全局流程 reset。
