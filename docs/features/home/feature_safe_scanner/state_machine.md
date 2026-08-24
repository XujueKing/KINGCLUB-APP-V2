# 安全扫码状态机

- 文档状态：`In Review`

```text
idleRationale
  -> requestingPermission
      -> cameraActive
      -> permissionDenied
      -> permissionPermanentlyDenied

cameraActive
  -> captured(single flight)
  -> resolving
      -> resolvedAllowed -> emit RouteIntent -> close overlay
      -> unsupported
      -> expiredOrUsed
      -> recoverableError
      -> sessionInvalid -> global reset

unsupported / expiredOrUsed / recoverableError
  -> cameraActive (重新扫码)
  -> close (回来源分支)
```

## 不变量

- 同一时刻最多一个 camera controller、一个 capture 和一个 resolver 请求。
- capture 后暂停识别，resolver 完成或用户明确重试后才恢复，避免同一码多次分流。
- 原始 payload 只存活在当前内存 attempt；不写文件、普通缓存、URI、日志、埋点或崩溃附件。
- `resolvedAllowed` 只表达类型化意图和不透明引用，不表达业务已成功。
- 页面关闭、进后台、session generation 改变或超过 attempt TTL 时销毁原始 payload 和引用。
- 未知枚举、协议版本、动作或目标一律失败关闭。

## 权限状态

- 首次进入显示用途说明，用户点击“开始扫码”后才请求相机权限。
- 临时拒绝允许再次请求；永久拒绝只提供“打开系统设置”和“返回”。
- 从系统设置回来重新读取权限，不假设已经授权。
- 权限对话框期间重复点击和系统返回由单一协调器处理。

## 生命周期

- 进入后台立即暂停相机和补光灯；回前台重新确认权限与 session 后再恢复。
- 离线可打开相机，但捕获后不能完成业务解析；页面保留内存 attempt 的时间上限由实现评审确定，超时必须重新扫。
- 页面 pop 后不得因迟到 resolver 响应再次导航。
