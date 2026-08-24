# 扫码数据、安全与 Fake 契约

- 文档状态：`In Review`

## 端口分层

```text
abstract interface ScannerPort
  permissionStatus() -> CameraPermissionStatus
  requestPermission() -> CameraPermissionStatus
  start(onCapture) / pause() / resume() / stop()
  setTorch(enabled)

abstract interface ScanResolverRepository
  resolve(rawPayload, attemptId) -> ScanResolution
```

UI/Mock 阶段使用 `FakeScannerPort` 与 `FakeScanResolverRepository`，不声明相机权限、不加载真实扫码插件、不访问网络。

## 当前建议的数据模型

```text
ScanResolution
  resolutionId             不透明、短期、单会话
  kind                     friendProfile | tableOrdering | admissionContext
  scanContextRef           不透明内存引用/短期令牌，不放 URI
  displayCategory          稳定、可本地化的说明类别
  expiresAt

ScanFailure
  category                 malformed | unsupported | expired | alreadyUsed |
                           wrongApp | offline | timeout | unavailable | sessionInvalid
  retryable
  requestId?               仅供客服，禁止包含 payload
```

## 客户端预校验

- 限制输入字节长度、编码和支持的二维码格式；拒绝条形码、空值、控制字符和异常 Unicode。
- 可以识别协议 envelope 的固定 scheme/version，但不能从 payload 决定路由、用户身份、桌台、金额或业务成功。
- 即使 envelope 本地验签通过，也必须由 resolver 复核用途、有效期、撤销、对象权限和当前 App。

## 路由交付

| kind | 类型化意图 | 参数 |
|---|---|---|
| friendProfile | `openFriendPreview` | 仅内存 `scanContextRef` |
| tableOrdering | `openScanOrdering` | 仅内存 `scanContextRef` |
| admissionContext | `openAdmissionTicketFromScan` | 仅内存 `scanContextRef` |

目标页面必须再次向自己的 Repository 读取权威对象；不得从 scanner ViewModel 复制用户、桌台、价格、订单或票状态。

## 日志与埋点

- 允许：页面打开来源类别、权限结果、扫描格式类别、resolution kind、失败 category、耗时桶、是否重试。
- 禁止：原始 payload、二维码图像、账号、桌台/门店 ID、票码、签名、resolution token、服务端原文。
- `attemptId` 仅进程内关联，不能作为跨会话用户标识。

## 未来真实接口边界

- 当前未分配或实现扫码 resolver K 接口。
- resolver 是登录后超级接口能力，身份来自可信 Session；请求不得提交 `userAccount` 作为授权依据。
- 真接口必须有 payload 大小限制、速率限制、防重放、过期/撤销、对象权限、审计和统一错误映射。
- 解析成功不等于消费成功；所有写操作由目标业务功能单独定义幂等与确认。
