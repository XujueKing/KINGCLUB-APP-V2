# 紧凑封面入口与系统相册验收

日期：2026-08-29
设备：Android 真机，1080 × 2400 px（约 432 × 960 logical px，density 2.5）
范围：系统相册本地单选与当前运行期预览；无媒体上传、相机、裁剪或资料接口。

## 验收结果

- “更换封面”胶囊的图标、字号和内边距均缩小，黑金样式保持不变。
- 点击封面入口成功打开 Android 系统 Photo Picker。
- 选择一张相册图片后立即在编辑页预览；点击保存后“我的”主页显示同一图片。
- 系统相册取消由 Widget 测试覆盖，不产生脏状态。

## 真机截图

- [紧凑封面按钮](01-compact-cover-button.png)
- [Android 系统相册](02-system-photo-picker.png)
- [相册图片预览](03-gallery-image-preview.png)
- [保存后主页封面](04-profile-saved-gallery-cover.png)

## 自动化与构建

- `flutter test test/edit_profile_flow_test.dart test/app_smoke_test.dart`：52 项通过。
- `flutter analyze`：无问题。
- `flutter build apk --debug --flavor preview --target-platform android-arm64`：通过。
- APK 已安装到真机 `e1c31301`，系统相册打开、选择、预览和保存流程通过。

final result: passed
