# KC-P-011 首页 UI Mock 验收记录

- 日期：2026-08-28
- 结果：`UI Mock Implemented`
- 设备：Android Emulator，1080×2400
- 数据：全部为本地 Fake，未连接真实接口、WebSocket、定位或运营网页

## 设备截图

1. [首页默认态](qa/2026-08-28/01-ready.png)
2. [运营内容展开与关闭](qa/2026-08-28/02-campaign-preview.png)
3. [滚动后的运营海报区](qa/2026-08-28/03-promotion-scroll.png)

## 通过项

- 旧版顶部 Logo、性别素材、等级、金币、钻石和进度层次可见。
- Banner、三联入口、两列海报和五 Tab 悬浮底栏在设备上无裁切、重叠或溢出。
- 运营卡可展开、阅读、关闭，关闭后保留原滚动位置。
- 三联入口有 300ms 重入保护；重选首页 Tab 回顶。
- 加载、长昵称、大余额、认证、未指定性别、空内容、局部图片错误、离线缓存、全页错误、图文、视频和会话失效均有自动化覆盖。
- 360、393、430dp 与 200% 文字无溢出；减少动画时 Banner 不自动轮播。

## 验证结果

- `flutter analyze`：通过，0 issue。
- `test/home_flow_test.dart`：10/10 通过。
- `test/home_legacy_visual_test.dart`：通过，已更新旧性别图标和 Banner 指示点的有意变更基线。
- 全量回归中发现并修复首页快捷入口延时锁在页面销毁后留下 Timer 的问题。
- 项目全量 `flutter test`：233/233 通过。

## 剩余门禁

- 用户原参考截图未作为当前审计的本地源文件保留，因此 `design-qa.md` 中的严格像素级并排对比仍保持 `blocked`。
- VoiceOver/TalkBack 还需在真机上完成最终读屏复核。
- 上述两项不改变页面 `UI Mock Implemented` 状态，但仍阻止项目级 `UI Flow Approved`。
