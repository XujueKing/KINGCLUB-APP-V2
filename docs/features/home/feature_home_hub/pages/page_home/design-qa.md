# Legacy Home Replica v1 视觉 QA

- 日期：2026-08-28
- 当前结果：`blocked`（功能性 UI Mock 已验收；严格像素并排对比待补）
- 参考：用户提供的旧版微信小程序首页截图
- 实现基线：`test/goldens/home_legacy_393x852.png`
- Android 实现截图：`qa/android_home_1080x2400.png`

## 已通过的检查

- App 内未绘制手机外框、系统状态栏内容或微信右上角胶囊。
- 顶部恢复旧版 Logo、认证、等级、金币、钻石和经验条。
- 首屏顺序恢复为 Banner、三联入口、两列运营海报。
- 底栏恢复旧版悬浮胶囊以及首页、消息、内容爱心、储物柜、我的五个位置。
- 中央白底粉色爱心为内容 Tab，不再映射安全扫码。
- 393×852 Golden 无布局溢出；Flutter analyze 和 Widget 测试通过。
- Android 37 语义树确认全部首屏元素与五个 Tab 已渲染并具备点击区域。
- Android 37 模拟器冷重启后已成功捕获完整设备实现截图，页面不再黑屏。
- 2026-08-28 新增设备默认态、运营详情和滚动区截图，见 [ui-audit.md](ui-audit.md)。
- HOME-M01～M14、360～430dp、200% 文字和减少动画均已自动化覆盖。
- 三联入口字体、比例、旧 PNG、按压态和 3/6/9 秒连续流光已完成独立复核，结果见 [components/component_quick_actions/design-qa.md](components/component_quick_actions/design-qa.md)。

## 黑屏排查记录

- 症状：Android 状态栏可见，Flutter 页面像素层全黑，但语义树与点击区域完整存在。
- 排除：Flutter analyze、Widget/Golden 测试、图片资源加载和页面语义均正常；移除底栏模糊后热重启仍黑。
- 处理：冷重启 Android 模拟器并重新运行应用后，Flutter Surface 恢复正常合成。
- 稳定性调整：底栏实时 `BackdropFilter` 已改成视觉接近的深棕实底和阴影，降低模拟器图形后端压力。

## 当前阻断

- 原参考截图未作为当前审计的本地源文件保留，无法按同视口生成参考图 + 实现图的组合对比证据。

## 下一次 QA

1. 若需严格 1:1 像素验收，将原参考图保存到本页 `qa/reference/` 下。
2. 用同视口并排对比后，修正可见差异并重新捕获。
3. 像素对比通过后把本文件最终状态改为 `passed`。

当前 `blocked` 只阻止严格像素验收和项目级 `UI Flow Approved`，不撤销已完成的 `UI Mock Implemented`；真实接口仍不得接入。
