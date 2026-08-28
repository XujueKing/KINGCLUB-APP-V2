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

设备证据：[Android 关于与法律页](screenshots/android_about_legal_v2.png)。自动化证据：`test/about_legal_flow_test.dart` 9 项；项目全量 172 项通过，`flutter analyze` 无问题。
