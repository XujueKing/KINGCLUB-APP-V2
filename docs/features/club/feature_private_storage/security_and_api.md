# 2026-09-12 更新

列表/详情/签码已接真实会话接口 K260912000401/402/403，下面Fake描述只保留作早期设计记录。凭证30秒、后台隐藏、每次签发撤销旧码；余额由服务端事务写入。

# 储物安全与 Fake 契约

- `StorageItemRef`：不透明、当前会话所有权。
- `StorageItemView`：type、名称、数量/剩余量、storedAt、expiresAt、status、allowedActions。
- `PickupDisplayToken`：不透明、expiresAt、refreshAfter、credentialVersion。
- 状态：`available/partiallyAvailable/pickupPending/collected/expired/suspended/disputed`。
- ports：`StoragePort.list/detail/issuePickupToken/reconcile`；UI 阶段全部 Fake。
- token 禁止日志、埋点、复制、分享、持久化；后台立即遮盖销毁。
