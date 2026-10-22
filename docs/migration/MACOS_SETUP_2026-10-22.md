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
- 已通过 Xcode 账户完成 Apple Development 证书配置。Runner 的 Debug/Profile/Release 使用公司团队 `239E9W6PEN` 自动签名；未运行仅供一次性 GitHub runner 的 `prepare_ios_signing.py`。
- Android SDK 和 Chrome 尚未安装；本次配置范围为 iOS/Xcode。Flutter 会提示未来版本停止 Intel Mac 支持，当前项目固定版本仍可运行。
- `pod install` 成功。模拟器构建重试通过，产物 `build/ios/iphonesimulator/Runner.app`。Simulator 窗口黑屏经切换集成显卡并重启后由用户确认恢复；GPU 策略为 `com.apple.CoreSimulator / FramebufferServerGPUPolicy = [lowPower]`。
- 仓库内容检查发现基线已跟踪两张被忽略的 party-commerce 截图（01-eat-play-design.png、02-merchant-design.png），本次未修改这些历史附件。

## iPhone 真机调试

用户已连接 iPhone 16 Pro，信任配对、开发者模式和开发者磁盘映像均已就绪。真机签名构建通过，调试包已安装；沿用 `com.lingmei.kingclub` 覆盖安装，不卸载或清除应用数据。

```sh
cd ~/Projects/KINGCLUB-APP-V2
flutter run -d 00008140-000C44542E29801C --debug --no-pub \
  --dart-define=KINGCLUB_API_BASE_URL=https://api.wuyexin.cn
```

首次手工 xcodebuild 出现 Flutter 模块未就绪，补齐真机引擎后完整 Flutter 构建成功。若后续手工构建再次缺少引擎框架，先用 `flutter build ios --debug --no-codesign` 完成准备，再使用自动签名运行。Debug 包使用 pubspec 当前版本 1.0.0+1；它是本机调试包，不代表新的商店发布版本。
