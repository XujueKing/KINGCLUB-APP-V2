# Windows 开发与 Xcode Cloud 构建

## 当前状态（2026-10-22）

用户要求继续在 Windows 开发 Flutter/Android，iOS 迁移至 Apple Xcode Cloud，减少对 GitHub Actions macOS 额度的依赖。仓库已增加 Xcode Cloud post-clone hook；云端工作流尚未激活，不能将脚本准备完成当作云端首构建通过。

通过 App Store Connect API 核实：应用 ID `6745736540`，显示名 KINGBAR，bundle ID `com.lingmei.kingclub`；公司团队 `239E9W6PEN`。当前未创建 ciProduct，GitHub provider 已存在但未返回可用仓库。该 API 可管理已创建产品的工作流，首次产品接入需从 Xcode 完成。

Apple Developer Program 包含每月 25 个 Xcode Cloud 计算小时，未用完不结转；这是会员包含额度，不代表已核实本团队当月剩余额度。不要自动订阅付费计划。

## 仓库脚本

`ios/ci_scripts/ci_post_clone.sh` 在 Apple 克隆仓库后运行，固定 Flutter 3.47.1/6655482ec06e547f90abf8ae7590466f4415978d，解析锁定依赖、应用既有 iOS 26 裁剪补丁、生成 Release 构建配置并安装锁定 Pods。最后由 Xcode Cloud 自身执行 Archive、托管签名和 TestFlight 交付；脚本不调用 `flutter build ipa` 二次归档，也不导入任何 .p12 或上传 API 私钥。

`configure_cloud_build.py` 在开始下载前校验版本、团队、构建号和地图参数。参数文件只写入临时目录且权限 600，脚本不输出地图 key。默认接口必须保留 `/kingclub-v2`，经营接口显式使用 `/commerce`。

## 首次接入设置

已通过 GitHub CLI 验证本机登录为 `XujueKing`，本次配置及此前 macOS 配置已推送至 GitHub main（`aa71397d`），并通过 `ls-remote` 核对。尚未完成的是 Apple 侧首次产品/工作流接入。打开 `ios/Runner.xcworkspace`，按 Command+9 打开 Report navigator（报告导航器），选择 Cloud → Get Started；已接入产品也可从 Integrate → Create Workflow 创建：

| 项目 | 设置 |
| --- | --- |
| App / 团队 | KINGBAR / com.lingmei.kingclub / 239E9W6PEN |
| 仓库与分支 | XujueKing/KINGCLUB-APP-V2，main |
| Workspace / Scheme | ios/Runner.xcworkspace / Runner |
| Xcode | 稳定版 26 或以上；首次优先与本机 26.5 对齐 |
| Action | iOS Archive / Release |
| Next Build Number | 200 或更大；不要从 1 开始 |
| 触发条件 | 初期手动，确认成功后再配置 main 的 iOS/Flutter 文件变更触发 |
| Post-action | TestFlight 内部测试；不自动提交 App Store 审核或发布 |
| Secret 环境变量 | KINGCLUB_TENCENT_MAP_KEY，与现有 CI 使用同一个有效的 iOS 腾讯地图 key |
| 普通环境变量 | KINGCLUB_BUILD_NAME=1.2.0；KINGCLUB_IOS_SYSTEM_CALLS=false |

首次需在 Apple/Xcode 界面授权 GitHub 仓库访问；保留现有 GitHub Actions 与证书，不撤销原 CI 签名身份。Xcode Cloud 自动签名不需要把旧 .p12 再上传给 Apple。

可选自动触发只包含 `lib/**`、`ios/**`、`assets/**`、`pubspec.yaml`、`pubspec.lock` 和相关构建脚本；Android 专属修改和文档修改无需启动 iOS 构建，避免浪费额度。首次不要加入多设备并行测试或每次推送全量测试矩阵。

## 日常 Windows 流程

1. 在 Windows 的同一个 main 分支开发 Dart/UI/Android，完成相应检查并推送 GitHub。
2. 在 App Store Connect 的 Xcode Cloud 工作流中手动启动构建，或使用之后配置的 main 变更触发。
3. Archive/签名通过后等待 TestFlight 处理，内部测试员在 iPhone 安装。
4. Flutter iOS 热重载、原生断点调试仍需连接 Mac；云构建不是远程交互式 iPhone 调试器。

## 验证边界

脚本语法、配置校验与本地 hook 演练不能代替 Apple 云端首构建。最终需核实一次真实云端构建、TestFlight 可安装和真实业务页面；只有这些完成后才标记云端交付可用。

2026-10-22 已在独立本地副本以测试地图参数、构建号 200 完整运行 post-clone hook，Flutter Release 配置与 `pod install --deployment` 成功；四项配置测试和脚本语法检查通过。Pod 命令必须在 `ios` 工作目录执行，保证 Flutter Swift Package Manager 插件路径解析正确。仓库内容门禁仍被基线中两个已跟踪的 party-commerce 设计 PNG 命中，未删除这些现有设计资料。

参考：[Apple Xcode Cloud 额度](https://developer.apple.com/xcode-cloud/get-started/)、[Flutter Xcode Cloud 指南](https://docs.flutter.dev/deployment/cd)、[Apple 自定义构建脚本](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)。
