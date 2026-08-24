# 数据、Repository 与待建接口契约

- 文档状态：`In Review`
- 契约性质：UI Mock 的批准候选；真实 K 接口尚未编号、登记或实现

## 1. 页面领域模型

```text
OnboardingSnapshot
  stage
  draftVersion
  kycStatus
  completedSections[]
  editableSections[]
  imageSlots[]              slot/status/mediaRef?，不含本地路径
  preferenceSelections      category -> optionId[]
  review?                   status/submittedAt/updatedAt/reasonCategory/canResubmit/resubmitAfter

PreferenceOption
  optionId
  category                  style | music | drink | event
  label
  enabled
  sortOrder
  catalogVersion
```

## 2. 客户端端口

```text
OnboardingRepository
  getSnapshot()
  startIdentityVerification(consentVersion)
  completeIdentityVerification(verificationRef)
  createMediaUploadIntent(slot, metadata)
  commitMedia(mediaRef, slot, draftVersion)
  removeMedia(slot, draftVersion)
  getPreferenceCatalog(locale)
  savePreferences(categorySelections, catalogVersion, draftVersion)
  submitApplication(idempotencyKey, draftVersion)
  getReviewStatus()
```

UI Mock 使用 FakeOnboardingRepository、FakeIdentityVerification 和 FakeMediaPicker。真实 adapter 只能在项目达到 `UI Flow Approved` 后加入。

## 3. 当前建议的服务端语义

| 语义 | 鉴权 | 关键规则 |
|---|---|---|
| `membership.onboarding.get` | session | 身份来自可信上下文；返回 currentStep/version |
| `identity.verification.start/complete` | session + recent context | 不信任客户端年龄；供应商结果服务端验签 |
| `membership.media.intent/commit/remove` | session | 受控 MIME/大小/槽位；隔离对象存储；内容扫描 |
| `membership.preferences.catalog/save` | session | 只收 enabled optionId；乐观版本冲突 |
| `membership.application.submit` | session | 幂等、服务端验证完整性、原子建立审核申请 |
| `membership.review.get` | session | 只返回稳定原因分类和允许动作，不返回模型分数 |

正式 interfaceId、请求字段、错误码、上传供应商与 OpenAPI 必须由后端工作包另行评审，不能复用旧 `S231202502210648`、`isFaceVerificationApi` 或 `imageScoreApi`。

## 4. 错误分类

| 稳定分类 | 页面处理 |
|---|---|
| `ONBOARDING_VERSION_CONFLICT` | 重新拉 snapshot，提示资料已更新 |
| `IDENTITY_INPUT_INVALID` | 字段级提示，不记录原值 |
| `IDENTITY_VERIFICATION_FAILED` | 可重试/人工处理按服务端动作 |
| `IDENTITY_AGE_RESTRICTED` | 进入不符合成年条件状态，不显示推算细节 |
| `MEDIA_TYPE_OR_SIZE_INVALID` | 图片槽位内提示 |
| `MEDIA_CONTENT_REJECTED` | 使用稳定公开原因，允许按策略替换 |
| `PREFERENCE_CATALOG_STALE` | 刷新目录并保留仍有效选择 |
| `APPLICATION_INCOMPLETE` | 根据 missingSections 跳转，不自行猜测 |
| `APPLICATION_ALREADY_SUBMITTED` | 拉取 review 状态，视作幂等收敛 |
| `SESSION_REVOKED` | 全局清理并 reset 登录 |

## 5. Mock 目录

初始 Fake 可参考旧版选项，但仅作为待运营确认的目录版本 `legacy-seed-v1`。中文 label 不作为主键；停用选项仍可在历史快照中显示，但不可新选。
