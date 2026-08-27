# 黑名单页验收

- [x] 列表、搜索、分页、用户主页和解除流程明确
- [x] 解除不恢复好友、二次确认、幂等和版本规则明确
- [x] 空态、离线、并发变化、隐私和无障碍明确
- [x] 用户于 2026-08-25 批准 Relationship Wireframe v1 / Blacklist

未来 UI Mock 验证 REL-M09～M12；当前仍受全局文档门禁约束。

## UI Mock 实现验收（2026-08-27）

- [x] 按旧版 `pages/blacklist` 复刻返回/标题/添加顶栏、纵向用户行和粉色 switch
- [x] 复用旧版 `back.png`、`add.png`、`blacklist.png` 和 `touxiang.png` 资产
- [x] 通讯录恢复旧版“黑名单”入口，点击后进入本页
- [x] 点击用户行发出 `blockedByMe` 用户资料路由，不传递永久账号、手机号或 conversationId
- [x] 解除前显示“不会自动恢复好友”确认，处理中单行防重入
- [x] 解除成功后本地移除该行，末项移除后显示空态
- [x] 下拉刷新、顶部添加好友和返回路径使用 Fake/本地导航
- [x] Android API 37 竖屏截图已存档
- [x] 真实超级接口、WebSocket 和持久化保持阻断
- [ ] 等待旧版同页运行截图后完成最终 1:1 视觉验收
