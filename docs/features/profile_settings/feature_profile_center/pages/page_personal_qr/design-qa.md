# KC-P-042 Android 视觉检查

检查日期：2026-09-12

视口：Xiaomi 14 Pro，Android 16，`1080 × 2400 px`

实现截图：`C:\Users\Poplar\AppData\Local\Temp\kingclub_qr_corrected.png`

视觉基准：只读旧版 `C:\Users\Poplar\Desktop\KingClub-app\pages\mycode\mycode.wxml`、`mycode.wxss` 与原始 King Club 素材

## 已通过

- 标准返回键、居中标题、下移后的身份区、`80rpx` 头像、单行会员号、`500rpx` 白底画布、约 `412rpx` 黑色码区和旧版说明文案完整显示。
- 二维码中心使用旧版原始 `kingLogo.png`，尺寸约 `96rpx`；身份行、二维码和说明文案的纵向位置与用户图二一致。
- 二维码内容固定；页面重建和前后台切换不改变内容。
- 页面不显示倒计时、刷新、过期、离线、后台隐藏或短期安全说明。
- 无保存、分享、复制或扫码入口；UI/Mock 阶段不访问真实接口。
- `1080 × 2400 px` 真机首屏无裁切、溢出或错误返回层级。

## 自动化证据

- `test/personal_qr_flow_test.dart`：6 项通过。
- 个人信息、二维码与入口相关定向测试：13/13 通过。
- “我的”页面定向测试：3/3 通过。
- `flutter analyze`：无问题。

final result: passed
