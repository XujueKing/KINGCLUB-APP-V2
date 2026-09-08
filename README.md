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

## GitHub 文件范围与体积

GitHub 只保留源码、工程配置、运行必需素材、自动化测试及其基准图，以及必要的设计契约和文字验收记录。参考截图、录屏、UI 层级 XML 和设计附件放在项目外归档；临时文件、缓存和安装包属于本地生成文件，不再跟踪。

2026-09-08 清理的 572 个参考附件已同时从 GitHub 最新分支和本地项目目录移除，本地可恢复副本位于项目同级的 `KINGCLUB-APP-V2-reference-archive-20260908/`，保留原相对路径。历史验收文档中的附件链接不会随源码交付，需要查看项目外归档或重新执行验收。不要通过 `git add -f` 重新加入。完整规则见 [仓库内容策略](docs/REPOSITORY_CONTENT_POLICY.md)。

提交前先暂存修改，再检查将被提交的文件及体积：

```powershell
node scripts/check_repository_content.mjs
```
