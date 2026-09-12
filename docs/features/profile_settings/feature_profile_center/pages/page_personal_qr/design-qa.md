# KC-P-042 Android 视觉检查

检查日期：2026-08-28
视口：Android Medium Phone 1080×2400
截图：`screenshots/android_personal_qr_v2.png`

## 已通过

- 独立页面、用户信息、白底二维码区和旧版说明文案已复刻。
- 显示 10 分钟 Fake 倒计时，刷新会替换页面视觉状态。
- Fake 码不嵌入真实账号、Token、手机号或 URL；无保存、分享、复制入口。
- 后台切换立即隐藏二维码，回到前台自动销毁旧码并生成新码。
- 过期、离线、生成失败、刷新失败、迟到响应和会话失效均可由长按标题重复演示。
- 1080×2400 首屏无裁切、溢出或错误返回层级。

## 自动化证据

- `test/personal_qr_flow_test.dart`：9 项通过。
- 项目全量 172 项通过；`flutter analyze` 无问题。

final result: passed
