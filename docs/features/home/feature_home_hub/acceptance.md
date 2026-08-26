# 首页聚合功能验收

## 文档准入

- [x] 首页职责与旧 index 拆分边界明确
- [x] 旧版首页复刻边界、入口、返回和生命周期明确
- [x] HomeAction allowlist 与未知动作失败关闭明确
- [x] Repository、缓存、局部错误和 Fake 契约明确
- [x] HOME-M01～M14 可按复刻规范重置后执行
- [x] 用户于 2026-08-26 确认 `Legacy Home Replica v1`、不绘制微信胶囊和旧版五 Tab 语义
- [x] 用户于 2026-08-26 确认 `Legacy Home Component Content v1` 及五个独立组件文档

## UI Mock 验收

- [ ] 完整、空、局部错误、全页错误、离线和会话失效可演示
- [ ] 三联快捷入口只产生批准的 Fake RouteIntent
- [ ] 参考图与 Flutter 截图并排 QA 通过并生成 `design-qa.md`
- [ ] 多尺寸、200% 字体、VoiceOver/TalkBack 和减少动态效果通过
- [ ] 不访问真实首页接口、定位、运营网页或用户业务数据

当前整体布局与组件内容均已批准，允许按重置后的 HOME-M01～M14 继续 UI/Mock 实现；项目达到 `UI Flow Approved` 前不接真实首页接口。
