# 个人中心数据、Repository 与 Fake 契约

- 文档状态：`In Review`
- 契约性质：UI Mock 候选；真实 K 接口尚未编号、登记或实现

## 当前建议的模型

```text
MyProfileSnapshot
  profileVersion
  avatarRef?
  nickname
  bio?
  membershipBadge            approved，不暴露审核内部标签
  profileCompletionCategory  basic | good | complete
  serviceAvailability        order/asset/storage/settings -> available/reasonCategory
  updatedAt

EditableProfile
  profileVersion
  avatarRef?
  nickname
  bio?
  cityOptionId?
  districtOptionId?
  occupation?
  heightCm?
  preferences               category -> optionId[]

FriendInvite
  tokenRef                  仅内存，用于生成二维码
  displayPayload            不透明签名 envelope
  expiresAt
  inviteVersion
```

## Repository/port

```text
abstract interface ProfileRepository
  getMyProfileSnapshot(refreshPolicy)
  getEditableProfile()
  getProfileCatalogs(locale)
  createAvatarUploadIntent(metadata)
  commitAvatar(mediaRef, profileVersion)
  updateProfile(ProfilePatch, profileVersion, idempotencyKey)

abstract interface FriendInviteRepository
  issueFriendInvite(idempotencyKey)
  refreshFriendInvite(previousTokenRef?)
  revokeFriendInvite(tokenRef)

abstract interface ProfileMediaPicker
  pickAvatar() -> FakeSelectedMedia?
  cropSquare(media) -> FakeSelectedMedia?
```

## 更新规则

- `ProfilePatch` 使用稳定字段名，不接动态 index；服务端忽略客户端未批准字段并返回新 `profileVersion`。
- 保存使用 SingleFlight + idempotencyKey；版本冲突重新拉取，并让用户选择保留本地草稿或采用新版本。
- 头像 intent/commit 与资料 patch 分离；commit 成功后清理临时媒体，结果未知先查资料版本。
- 偏好复用 Onboarding 的 optionId/catalogVersion，不维护第二套中文字符串主键。

## Fake 契约

Fake 必须覆盖完整/缺资料、缓存、字段错误、目录失效、头像权限/格式/上传错误、版本冲突、结果未知、二维码签发/刷新/过期/撤销、离线和会话失效。

## 未来真实接口边界

- 当前 K101～K107 不包含个人资料编辑或好友邀请签发；不得把 K104 最小成员摘要扩成任意资料写接口。
- 真实接口身份来自可信 Session，不接收 `userAccount` 作为授权依据。
- 资料写接口必须有字段级权限、长度/目录校验、内容安全、幂等、版本冲突和统一错误码。
- 邀请 token 必须限定 `friendProfile` 用途、当前 App、过期时间和撤销状态；扫描成功不自动建立好友关系。
