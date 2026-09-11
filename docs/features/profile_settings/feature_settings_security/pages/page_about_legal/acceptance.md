# 关于与法律文档页验收

- [x] 构建版本、主体信息、目录和文档阅读态明确
- [x] 版本、生效日、缓存、失败和非法引用明确
- [x] K107/DocumentRef 与批准外链边界明确
- [x] 不硬编码旧正文、不执行任意 HTML/URL
- [x] 用户于 2026-08-25 批准 `Settings Wireframe v1 / About & Legal`

## UI Mock 验收

- [x] SETTINGS-M19～M22 可重复演示
- [x] 四类文档可在目录与阅读态间切换，返回层级正确
- [x] 离线可信缓存展示版本和生效日期，缓存过期拒绝展示正文
- [x] 无效 DocumentRef 与目录加载失败不会替换为空白法律正文
- [x] 会话失效清理临时引用，不执行 HTML、任意 scheme 或真实外链
- [x] 目录、阅读和重试页面使用正式发布占位文案，不在正常路径展示 Fake、Mock 或测试阶段说明

设备证据：[Android 关于与法律页](screenshots/android_about_legal_v2.png)。自动化证据：`test/about_legal_flow_test.dart` 9 项；项目全量 172 项通过，`flutter analyze` 无问题。

## 2026-09-12 小程序关于页复刻

- [x] 标题、径向背景、King Club 标志、品牌副标题和正文纵向节奏与用户截图一致。
- [x] 隐私政策与用户协议为蓝色下划线内联入口，可进入阅读态并正常返回。
- [x] 技术支持、版本、软著、电子版权、APP/小程序备案和开发商信息完整显示。
- [x] Android 真机同状态视觉复核、定向测试和 `flutter analyze` 通过。

## 2026-09-12 原版法律正文修正

- [x] 隐私政策标题栏、主标题、版本日期和首屏段落与用户图四一致。
- [x] 用户协议标题栏、主标题和首屏长段落与用户图五一致。
- [x] 两份正文使用旧版 `650rpx` 内容宽度及 H1/H2/H3/H8 字阶，不显示“预发布版”或“待权威目录确认”。
- [x] 两份正文均可完整滚动、返回关于页，Android 真机及定向测试通过。

设备证据：`C:\Users\Poplar\AppData\Local\Temp\kingclub_privacy_final3.png`、`C:\Users\Poplar\AppData\Local\Temp\kingclub_agreement_final.png`；同尺寸并排证据：`kingclub_compare_privacy_final.png`、`kingclub_compare_agreement_final.png`。自动化证据：个人信息、关于和 Shell 相关定向测试 26/26 通过；`flutter analyze` 无问题。
