# 设置与安全数据和 Fake 契约

## 模型

- `SettingsCapabilities`：paymentPinStatus、deletionAvailability、notificationPermission、appVersion
- `PaymentPinPolicy`：length=6、attemptState、allowedActions
- `DeletionPreflight`：eligible、blockers、retentionSummary、expectedVersion
- `DeletionRequestRef`：不透明、幂等可对账
- `LegalCatalogView`：DocumentRef、title、version、effectiveAt、required

## UI 阶段 ports

- `SessionControlPort.logout(idempotencyKey)/reconcileLogout(...)`
- `PaymentSecurityPort.status()/beginReauth()/setOrChange()/reconcile(...)`
- `AccountDeletionPort.preflight()/submit(...)/reconcile(...)`
- `LegalDocumentPort.catalog()/load(documentRef)`
- `LocalPreferencePort`：仅批准的播放声音、缓存清理等非敏感键
- `SystemSettingsPort.openNotificationSettings()`：UI 阶段 Fake

页面不得接受 userAccount、mobile、interfaceId 或任意 URL。真实 adapter 仍受全局门禁。
