# 路由与导航验收

## 文档准入

- [x] V1 路由目录、分区、类型化参数与导航动作明确
- [x] public/auth/protected/restricted 守卫决策和重定向不变量明确
- [x] 登录 FlowStore、`$extra` 缺失和外部直达失败关闭规则明确
- [x] returnTo、深链、推送、去重、待消费与权限复核规则明确
- [x] 登录成功、注销、撤销、过期、受限和未知路由清栈规则明确
- [x] Android/iOS 返回、生命周期与 V1 状态恢复边界明确
- [x] 单元、Widget、集成和真机测试矩阵可执行
- [ ] 用户批准本模块，状态更新为 `Approved for Development`

## 实现验收

- [ ] 所有已批准页面使用类型化 RouteData/RouteIntent，无散落字符串导航
- [ ] public/auth/protected/restricted 守卫矩阵全部自动化通过且无 redirect loop
- [ ] 敏感数据不进入 URI、深链、导航日志、崩溃附件或系统恢复状态
- [ ] returnTo、推送和深链只能解析为 allowlist RouteIntent，重复事件最多消费一次
- [ ] 登录成功、注销、撤销、过期和受限状态正确清栈
- [ ] auth flow 在进程重启、外部直达或缺失 `$extra` 时不可恢复
- [ ] Android/iOS 返回手势、冷/热启动深链、重复通知和前后台竞态通过集成测试

实现项在编码完成后逐项执行；当前勾选只表示文档内容已具备评审条件。
