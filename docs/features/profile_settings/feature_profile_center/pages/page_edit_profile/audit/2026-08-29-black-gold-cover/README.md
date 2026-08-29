# 编辑主页黑金主题与封面编辑验收

日期：2026-08-29
设备：Android 真机，1080 × 2400 px（约 432 × 960 logical px，density 2.5）
范围：UI / Mock，本轮未连接相册、上传、资料接口或生产 SDK。

## 验收结果

- 编辑主页、文字编辑弹窗和封面选择器已统一为黑金主题，已移除旧粉色视觉。
- 页面顶部可预览当前封面并打开“更换封面”。
- 封面选择器使用三张本地 Mock 图片，当前项以香槟金描边和勾选标识。
- 封面选择属于编辑草稿；保存后“我的”页面立即更新，取消或放弃编辑不会污染主页状态。
- 主页封面更新后，头像、身份文字、统计信息和资料面板的叠放关系保持不变。

## 真机截图

- [编辑主页黑金首屏](01-edit-profile.png)
- [黑金文字编辑弹窗](02-black-gold-dialog.png)
- [黑金封面选择器](03-cover-picker.png)
- [选中后的封面预览](04-cover-preview.png)
- [保存后主页封面](05-profile-updated-cover.png)

## 自动化检查

- `flutter test test/app_smoke_test.dart test/edit_profile_flow_test.dart test/profile_row_alignment_test.dart`：54 项通过。
- `flutter analyze`：无问题。

final result: passed
