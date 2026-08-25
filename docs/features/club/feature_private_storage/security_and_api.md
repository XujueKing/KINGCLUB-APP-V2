# 储物安全与 Fake 契约

- `StorageItemRef`：不透明、当前会话所有权。
- `StorageItemView`：type、名称、数量/剩余量、storedAt、expiresAt、status、allowedActions。
- `PickupDisplayToken`：不透明、expiresAt、refreshAfter、credentialVersion。
- 状态：`available/partiallyAvailable/pickupPending/collected/expired/suspended/disputed`。
- ports：`StoragePort.list/detail/issuePickupToken/reconcile`；UI 阶段全部 Fake。
- token 禁止日志、埋点、复制、分享、持久化；后台立即遮盖销毁。
