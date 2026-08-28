# KC-P-046 Android 视觉检查

检查日期：2026-08-28
视口：Android Medium Phone 1080×2400
实现截图：`screenshots/android_about_legal_v2.png`
复刻依据：旧版 `about.wxml/.wxss`、`aggreement/index.wxml/.wxss` 与已批准 `Settings Wireframe v1 / About & Legal`

## 对照结果

- 关于页保留旧版 KingClub 标志、版本、说明、协议入口、技术支持和主体信息结构。
- 四类文档均可在本页进入阅读态，返回先回目录再回设置。
- 阅读态展示标题、Fake 版本、生效日期、章节层级和滚动正文。
- 明确标注 UI Mock，不把示例正文冒充正式法律文本，不打开外链或执行 HTML。
- 目录首屏在 Android 实机尺寸下完整显示四类文档和主体信息，无裁切或横向溢出。
- 系统返回键先退阅读态再回设置页；长按标题可切换离线、过期、无效引用、加载失败和会话失效。

final result: passed
