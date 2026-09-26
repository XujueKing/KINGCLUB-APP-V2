# 群通话后台保持修正

群通话页面原先在 paused 时无条件挂断并永久设置 invalid。现有 NativeGroupCallMedia 已启动 Android CallForegroundService，因此旧页面行为既中断已建立的群通话，也让尚未发起通话的选人页面在返回后无法继续。

本次变更：
- 选人阶段未开始请求、未创建 session 时，切换后台不使页面失效。
- CallForegroundLease 仅在原生 start 成功返回且未关闭时报告 isActive；不支持的平台、启动中、启动失败、迟到成功均不报告有效。
- 群媒体存活且服务有效时允许 paused 保持；未就绪、无后台服务或 detached 仍执行原有停止流程。退出登录和离开页面的清理不变。

验证：call_foreground_lease、group_call_page、group_call_session、native_group_call_media 共 34 项通过，5 文件 analyze 无问题。新增覆盖选人后完整前后台切换仍可发起，以及服务确认前后、关闭、失败和不支持平台的状态。日志 build/group-background-test.log、build/group-background-analyze.log。

本节点未重新打包安装；双机锁屏长时间保持及通知返回待集中真机验收。它不提供进程被杀后的来电唤醒，系统离线推送仍后置。
