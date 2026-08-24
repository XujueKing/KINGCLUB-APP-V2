# 路由与导航验收

- [ ] 所有页面使用类型化 RouteData，无散落字符串路径
- [ ] public/auth/protected/restricted 守卫矩阵有单元测试
- [ ] 敏感数据不进入 URI、深链、导航日志或系统恢复状态
- [ ] returnTo、推送和深链只能解析到 allowlist RouteIntent
- [ ] 登录成功、注销、撤销、过期和受限状态正确清栈
- [ ] auth flow 在进程重启后不可恢复
- [ ] Android/iOS 返回、冷启动深链和重复通知有集成测试
- [ ] 用户批准 ADR-0001 与本模块，状态更新为 `Approved for Development`
