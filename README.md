# KingClub App V2

## 当前产品评审（更新至 2026-09-10）

新增[用户碎片需求台账](docs/product/2026-09-09-native-product-review/REQUIREMENT_INBOX.md)与[媒体/颜值/美颜及腾讯核身调研](docs/product/2026-09-09-native-product-review/MEDIA_AND_FACE_RESEARCH.md)，已同步 41 项产品需求与 ROADMAP。最新决定：**首版不做实名核身，沿用旧照片上传接口的方法**；管理能力纳入 App 授权角色范围。新增详细规格仍待审，未接真实服务。

请先看 [KING CLUB 原生产品评审包](docs/product/2026-09-09-native-product-review/README.md)：已整理需求、前后端重构方案、仅 KING CLUB 数据迁移方案、UI/流畅度验收标准和 [ROADMAP](docs/product/2026-09-09-native-product-review/ROADMAP.md)，状态为 `In Review`，等待用户检阅。

实际主目录为 `D:\WEB3_AI\KINGCLUB-APP-V2`。最新小程序 72 路由、酒吧分类 103 个快照接口加 3 个群管理增量、94 张 k_ 表/1484 字段均已登记；不迁移整份多网站混库。旧代码/存储过程允许重新设计，不要求照搬。当前 48 页 UI/Mock 不等于完整原生产品已完成。

KingClub iOS/Android 的 Flutter 重构工程。当前处于 `UI Mock In Progress`，只使用离线 Fake 数据，不连接真实超级接口、WebSocket、支付、推送或其他生产 SDK。

## 当前实现

最新工程状态见[2026-09-09 审计](docs/audits/2026-09-09-project-audit.md)和[小程序改进对照/修复批次](docs/audits/2026-09-09-miniprogram-alignment.md)。历史测试数量和单页截图不代表当前整 App 已通过验收；真实接入以[唯一交付账本](docs/v2/APP_SCOPE_AND_UI_DELIVERY_GATE.md)为准。

- Flutter 3.47.1 / Dart 3.13.1
- Riverpod 3 + code generation
- `go_router` 类型化路由
- Design System v1 深色主题
- 启动鉴权、手机号登录、验证码和协议只读 UI
- 实名成年核验、会员图片、两步偏好与审核状态五页 UI
- 五个底部主入口 App Shell，中央为内容；扫码从首页等独立快捷入口进入
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

2026-09-09 最近一次 App 验证为 `flutter analyze` 通过、329 项测试中 327 通过 / 2 项偏好 Golden 失败，Android preview Debug 构建通过；完整记录见上方审计与修复文档。本轮产品资料审查未重新进行 Android/iOS 真机 UI 验收，不代表达到 UI 99% 保真或生产发布条件。

产品、架构、页面和交付门禁从 [V2 总览](docs/v2/README.md) 与 [功能文档索引](docs/features/README.md) 进入。

## GitHub 文件范围与体积

GitHub 只保留源码、工程配置、运行必需素材、自动化测试及其基准图，以及必要的设计契约和文字验收记录。参考截图、录屏、UI 层级 XML 和设计附件放在项目外归档；临时文件、缓存和安装包属于本地生成文件，不再跟踪。

2026-09-08 清理的 572 个参考附件已同时从 GitHub 最新分支和本地项目目录移除，本地可恢复副本位于项目同级的 `KINGCLUB-APP-V2-reference-archive-20260908/`，保留原相对路径。历史验收文档中的附件链接不会随源码交付，需要查看项目外归档或重新执行验收。不要通过 `git add -f` 重新加入。完整规则见 [仓库内容策略](docs/REPOSITORY_CONTENT_POLICY.md)。

提交前先暂存修改，再检查将被提交的文件及体积：

```powershell
node scripts/check_repository_content.mjs
```
