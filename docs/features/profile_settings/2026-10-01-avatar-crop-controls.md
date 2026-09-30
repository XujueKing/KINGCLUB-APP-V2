# iPhone 头像裁剪返回与确认

用户截图中的“调整头像”原生裁剪页缺少返回和确认，无法退出或采用裁剪结果。Dart 已配置完成/取消文案；插件 image_cropper 12.2.1 使用 TOCropViewController >=3.1.2。上游 iOS 26 存在同类按钮缺失报告：https://github.com/TimOliver/TOCropViewController/issues/655 。

源码中 iOS 26 不创建旧文字按钮，而 showOnlyIcons 默认值的更新受编译 SDK 宏限制；较旧 SDK 构建在新系统运行时会选中不存在的文字控件。新版玻璃按钮也存在上游报告。不能只设置文案就宣称修好。

在 image_cropper 的原生配置末尾添加仅 iOS 26 启用的顶部“返回/确认”按钮，使用 UIKit 标准 UIButton 和安全区约束；隐藏底部重复完成/取消按钮，保留旋转、重置、缩放和 1:1 裁剪。返回复用原 cancel 回调，返回 null、不改变头像草稿；确认调用公开 commitCurrentCrop，只生成裁剪文件，仍需个人信息保存才上传，防重复确认。旧 iOS 与 Android 保留原生控件。

补丁脚本通过 package_config 定位锁定的 image_cropper 12.2.1，校验版本与插入位置，重复运行不重复插入；未知版本/源码变化报错，避免静默构建失效的包。签名与无签名 iOS 构建流程在依赖解析后统一应用补丁。本机仅 Windows，实际 Objective-C 编译以 macOS CI 为准；Flutter 配置/个人信息返回行为测试不等于原生按钮验收。提供截图只用于本机检查，不保存头像照片到 Git。

已验证：补丁脚本 3 项测试通过（幂等、拒绝未知源码/版本），对实际锁定插件源码内存应用验证通过且未修改本机依赖缓存；编辑资料流程 12 项测试通过，定向 Flutter analyze 无问题，git diff --check 通过。手工 macOS 构建也需在 flutter pub get 后执行 python3 scripts/patch_ios_avatar_cropper.py。

待验证：macOS CI 原生编译、iPhone 覆盖安装，以及真机按钮位置、返回不保存、确认裁剪可用。不得代用户提交真实头像修改。
