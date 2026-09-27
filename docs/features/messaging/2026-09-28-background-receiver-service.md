# 长时间后台消息接收（2026-09-28）

用户明确要求补齐长期后台保活，同时修复后台新来电与离线推送。采用用户可见、可停止的 Android specialUse 前台服务，真实用途是已登录即时通信的持续接收；不冒用麦克风、播放或 dataSync 类型。类型和用途须如实提交商店审核，不能承诺系统永不回收。

服务拥有独立 FlutterEngine，复用加密实时协议、当前安全会话和通知收件人校验。UI 前台由 UI 连接接收；UI 后台由服务连接接收。服务重建重新读取安全存储，退出账号停止，不把凭据放 Intent、日志或普通偏好。未登录不启动，用户停止后不自动重启，设置中可重新启用。通话服务仍只保护已接通的真实采集；新来电通过接收服务验证并通知，不能自动接听。

系统强制停止、厂商冻结或真正断网仍需恢复或厂商推送，不能把 START_STICKY 作为送达保证。后台周期核对未结束邀请，减少事件丢失导致的漏来电。实机持续锁屏、进程回收恢复及厂商离线送达需分别记录。

依据：https://developer.android.com/develop/background-work/services/fgs/service-types

## 本轮真机结果

- A、B 均安装独立接收服务版本，系统服务记录显示前台服务运行。
- B 初次退到桌面后未持续接收。ColorOS 的 OplusHansManager 日志确认冻结应用，返回前台时解冻（冻结约 435 秒）；不能把常驻通知当成后台执行成功。
- 在 B 的应用详情 → 耗电管理中开启“允许应用后台行为”后，后台周期任务持续运行。05:24:45、05:25:48 两次收到 chat.changed，均 messageEligible=true、localShown=true；后一次处于锁屏测试阶段。
- 05:26:28 收到 chat.call.changed，localShown=true；随后进入通话服务。会话记录显示本次语音通话 00:03。此记录只证明本次后台来电链路，不替代长时间通话音质验收。
- 设置页增加后台接收开关、系统应用详情入口和耗电提示。停止动作会持久保存停用状态，不通过假音频等方式绕过用户选择。
- 13 项已有通知、横幅、角标和通话服务租约测试通过。Profile 包构建通过。

未完成验证：数小时锁屏及耗电、系统回收后重建、进程退出时厂商推送可靠性、后台视频来电。A 后续 ADB 一度 offline，使用指定设备 reconnect 后恢复，未清数据或要求重新登录。

## 通知点击错误页修复

用户报告的“花屏”已从 B UI dump 确认是 Page Not Found / GoException。旧通知用 kingclub://notification/… 区分 PendingIntent，Flutter 自动深链将其交给 GoRouter，和受校验的 ChatPushOpen 跳转竞争，导致错误页及返回异常。

新通知改用显式 Intent action 区分身份，不携带合成深链；MainActivity 在冷启动、onNewIntent 交给 Flutter 前移除旧版内部通知 URI，保留原始推送 payload，由既有账号、有效期和会话校验决定跳转。未放宽校验或添加任意网址路由。

B 覆盖安装后，实际 A→B 新消息通知点击进入正确会话，返回到聊天列表，UI dump 无错误页。20 项 push-open runtime/recovery 测试通过，最终 Kotlin 增量 Profile 构建通过。A 同步覆盖安装此修正版。
