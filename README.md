# KingClub App V2

KingClub iOS/Android 的 Flutter 重构工程。当前处于 `UI Mock In Progress`，只使用离线 Fake 数据，不连接真实超级接口、WebSocket、支付、推送或其他生产 SDK。

## 当前实现

- Flutter 3.47.1 / Dart 3.13.1
- Riverpod 3 + code generation
- `go_router` 类型化路由
- Design System v1 深色主题
- 启动鉴权、手机号登录、验证码和协议只读 UI
- 实名成年核验、会员图片、两步偏好与审核状态五页 UI
- 四主目的地 App Shell 与中央扫码入口
- 首页品牌头部、四个核心入口、今晚行程、精选活动与服务提示 UI
- 安全扫码全屏页、Fake 权限/取景器、三类 allowlist 分流与异常恢复 UI
- 只读发现作品流、纵向切换、首次静音、播放生命周期与异常/低流量 UI
- KingClub 好友通讯录、备注/昵称搜索、分组索引与离线/关系变化 UI
- Mock 验证码：`888888`
- 登录异常场景：手机号尾号 `001/002`，验证码 `111111/222222/333333`

## 运行与验证

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
flutter run
```

Android/iOS 包标识当前沿用旧版 `com.lingmei.kingclub`，用于保留未来覆盖升级可能；正式签名、推送配置与商店发布仍需单独确认。

当前 `flutter analyze` 与 6 条 Widget 测试已通过，其中一条覆盖从手机号登录、四步准入、审核通过到 App Shell 的完整旅程，并覆盖安全扫码、只读发现作品流与通讯录隐私搜索边界。Android API 37 模拟器、Debug APK 与实机 UI 截图均已验证；Gradle 9.3.1 使用带官方 SHA-256 校验的国内镜像下载。

产品、架构、页面和交付门禁从 [V2 总览](docs/v2/README.md) 与 [功能文档索引](docs/features/README.md) 进入。
