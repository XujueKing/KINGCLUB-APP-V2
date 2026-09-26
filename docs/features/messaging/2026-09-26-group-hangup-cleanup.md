# 群通话挂断异常收尾

GroupCallSession 原先在 try/finally 外等待原生媒体 close。如果清理抛错，会跳过服务端 leave/decline 和控制器关闭；连续调用 hangUp 也可能排入重复退出操作。

现在挂断共享同一 Future，先停止本地采集，捕获清理错误后继续尝试服务端退出，finally 关闭控制器和媒体，仍向调用方报告失败，不伪造退出成功。加入请求未结束时，仍等待其返回后根据真实成员状态选择 leave/decline。

验证：group_call_session、group_call_controller、native_group_call_media、group_call_page 共 40 项通过；2 文件 analyze 通过。新增原生清理报错仍退出服务端并关闭控制器的回归，以及加入中重复挂断只产生一次 leave。测试夹具明确注入模拟设备和采集，避免访问真实 WebRTC 平台通道。

日志：build/group-hangup-test.log、build/group-hangup-analyze.log。本次未单独构建安装；与上一节点后台保持修正一起集中真机验收。系统离线来电推送不在此变更内。
