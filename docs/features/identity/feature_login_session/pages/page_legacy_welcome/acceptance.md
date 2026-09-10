# 旧版欢迎封面页验收

## 2026-09-10 有声视频封面

- 用户明确选择游戏式开场：默认带声音循环播放，右上角可静音；不修改系统音量。
- 素材 `assets/legacy/home/welcome_cover.mp4`：原 25,307,439 字节，压缩后 4,678,810 字节，缩小 81.5%；960×2148、30fps、20.2 秒保持原样。
- H.264 使用 `libx264 -preset slow -crf 25 -pix_fmt yuv420p -movflags +faststart`；AAC 44.1kHz 立体声音轨使用 `-c:a copy`，原文件保留项目外。视频为有损压缩，不能称绝对无损。
- 原/新音频码流 SHA-256 相同：`011612179ad1809f7a77af04c36990aef7ada9d30edcb756f76c7a5e29e64188`；整段 606 帧及音轨解码通过，8 秒位置并排抽样检查无明显构图/色彩变化，不代表逐帧视觉无损或首尾无缝。
- `flutter analyze --no-pub` 通过；`flutter test --no-pub test/welcome_video_test.dart` 两项通过，覆盖加载期间切页、返回续播、默认有声、静音、后台暂停/恢复、销毁及解码失败兜底。
- 当前 ADB 无设备，安卓实机试听、音视频循环衔接与 iOS 实机仍待验收，不标记通过。
- Android preview Profile/AOT APK 已构建成功，保留 `KINGCLUB_API_BASE_URL=https://test.wuyexin.cn/kingclub-v2`，可继续真实短信联调；包内视频哈希与本次压缩素材一致。产物 `build/app/outputs/flutter-apk/app-preview-profile.apk`，不提交安装包。

以下为静态封面阶段历史记录；视频封面按最新用户批准覆盖背景素材要求。

- [x] 已使用旧版 `bj.jpg` 与 `logo_1.png` 作为唯一视觉素材基准
- [x] 已冻结协议、NEXT、营业时间的层级和比例
- [x] Android 目标视口下背景完整覆盖且不留白；iOS 实机比例待后续设备验收
- [x] 协议链接、勾选和 NEXT 返回路径可用
- [x] 2026-09-10 真机反馈后将完整协议行固定为单行，窄屏整体缩放且两个链接仍可分别点击
- [x] 2026-09-10 按旧版 CSS 恢复 20dp 小圆框、居中小勾、`#C9B69E` 文案及 80%×45dp 的 NEXT 比例
- [x] 2026-09-10 实机微调协议行至 15dp、营业时间至 13dp、勾选视觉至 18dp，并增加链接字底与下划线间距
- [x] 不显示微信宿主胶囊或任何 UI 测试说明
