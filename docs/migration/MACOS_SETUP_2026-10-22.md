# macOS 开发环境迁移（2026-10-22）

原项目 `/Volumes/D/WEB3_AI/KINGCLUB-APP-V2` 位于只读 NTFS 卷。保留原目录，在 `/Users/rainbowharubo/Projects/KINGCLUB-APP-V2` 建立可写开发副本，保留本机源码和 Git 历史，继续使用 main。未复制 Windows 构建缓存，未从远端覆盖工作文件。

## 已安装与配置

- macOS 26.7.1，Intel x86_64。
- Xcode 26.5 (17F42)，开发目录 `/Applications/Xcode.app/Contents/Developer`；首次启动组件检查通过。
- iOS 26.5 模拟器，iPhone 17 Pro。
- Flutter 3.47.1 stable，提交 `6655482ec06e547f90abf8ae7590466f4415978d`，Dart 3.13.1；SDK 路径 `~/develop/flutter`。
- CocoaPods 1.17.0，用户目录 `~/.gem/ruby/2.6.0/bin/pod`。使用与系统 Ruby 2.6 兼容的依赖；未覆盖系统 Ruby。
- `~/.zprofile` 加入 Flutter 与 CocoaPods PATH。VS Code 已安装 Flutter/Dart 扩展并配置 SDK 路径。
- 开发副本的 Git 本地配置 `core.autocrlf=true`，避免已复制的 CRLF 文件产生整库差异。
- `flutter pub get --enforce-lockfile` 成功，未升级依赖；已应用仓库既有 `scripts/patch_ios_avatar_cropper.py`。
- iOS 继续使用 Swift Package Manager；不支持 SPM 的 get_thumbnail_video、tobias 通过 CocoaPods 接入。补充 Podfile 和 xcconfig 的 Pods 引用，最低 iOS 15。

## 常用命令

```sh
cd ~/Projects/KINGCLUB-APP-V2
flutter pub get --enforce-lockfile
python3 scripts/patch_ios_avatar_cropper.py
flutter build ios --simulator --debug
open ios/Runner.xcworkspace
```

直接构建/运行默认使用项目现有 Mock 配置。需要联调真实服务时，显式传入 `--dart-define=KINGCLUB_API_BASE_URL=https://api.wuyexin.cn`，并沿用相应功能需要的其他构建参数。不要将历史 CI 的 test 域名视为当前入口。

## 验证与限制

- `flutter doctor -v` 的 Xcode 项通过，识别 CocoaPods 1.17.0。
- `dart analyze` 无 error/warning，17 条已有 info 级风格提示，未在环境迁移中修改业务代码。
- 本机无可用 Apple 代码签名证书。真机签名需在 Xcode Settings → Accounts 登录所属开发者账户并下载/创建相应证书和描述文件；不得运行仅供一次性 GitHub runner 的 `prepare_ios_signing.py` 修改本机钥匙串。
- Android SDK 和 Chrome 尚未安装；本次配置范围为 iOS/Xcode。Flutter 会提示未来版本停止 Intel Mac 支持，当前项目固定版本仍可运行。
- `pod install` 成功。首次模拟器构建已生成应用主体，但 ibtool/actool 等待 CoreSimulator 辅助工具连接，尚未验证完整构建成功；已重启用户 CoreSimulator 服务并重试。重试日志 `/tmp/kingclub-ios-retry.log`，依赖和构建缓存保留。
- 仓库内容检查发现基线已跟踪两张被忽略的 party-commerce 截图（01-eat-play-design.png、02-merchant-design.png），本次未修改这些历史附件。
