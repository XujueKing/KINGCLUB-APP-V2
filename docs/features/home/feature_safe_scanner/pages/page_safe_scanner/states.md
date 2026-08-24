# 扫码页状态

| 状态 | UI | 动作 |
|---|---|---|
| `rationale` | 用途说明、隐私提示 | 开始扫码、关闭 |
| `requestingPermission` | 稳定 loading | 关闭由协调器处理 |
| `cameraActive` | 预览占位、扫码框、可选补光灯 | 捕获、关闭 |
| `capturedResolving` | 冻结画面/遮罩、正在识别 | 关闭并使 attempt 失效 |
| `permissionDenied` | 拒绝说明 | 再次请求、关闭 |
| `permissionPermanentlyDenied` | 设置说明 | 打开设置、关闭 |
| `unsupported` | 不适用/无法识别 | 重新扫码、关闭 |
| `expiredOrUsed` | 过期/已使用稳定说明 | 重新扫码、关闭 |
| `recoverableError` | 离线/超时/不可用 | 重试解析、重新扫码、关闭 |
| `navigating` | 单次导航锁 | 无重复动作 |
| `sessionInvalid` | 清理预览与 payload | 全局 reset |

## 状态优先级

`sessionInvalid > appBackgrounded > permission > resolving > cameraActive`。高优先级状态出现时必须停止低优先级异步结果更新 UI。

## 失败关闭

- 未知 error code 映射为 `recoverableError/unavailable`，不显示服务端原文。
- 未知 resolution kind 映射为 `unsupported`，不尝试通用导航。
- 解析成功但目标页面尚未批准/不可用时显示“当前版本暂不支持”，不把引用交给其他页面。
