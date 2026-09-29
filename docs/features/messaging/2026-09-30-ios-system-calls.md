# iOS 系统来电接入（进行中）

用户明确要求 PushKit/CallKit、持续来电、系统接听/拒绝，并修复铃声、震动和
KING 图标；普通 APNs 横幅送达不算通话验收。当前阶段尚未达到真机验收。

原生入口 `AppleSystemCalls.swift` 在 App 启动早期创建 CXProvider，并通过
`kingclub/system-calls` 接到 Flutter。VoIP 注册必须显式 bind 已认证账号；
当前尚未在 Dart 运行时调用 bind，因此不会向未完成的通话流程投递真实来电。
已有普通 APNs 和通话后台音频继续保持原路径。

VoIP 格式与服务端 `kingclub_call` 对齐：version、callId、recipient、scope、
video、expiresAt；不传姓名、群名、聊天内容。每次 PushKit 到达先报告系统来电，
随后处理失效/账号不匹配/重复/忙线。Flutter 尚未启动时保留事件；接听与拒绝
保留原生 action，待业务确认后 fulfill，失败或超时结束系统界面。
邀请截止后停止系统来电，注册账号改变时结束原账号所有来电。

本批使用系统默认铃声与系统触感策略；尚未完成自定义 KING 单色来电图标，
不能称铃声/震动问题已修复。系统静音、专注模式等仍由 iOS 控制。

还需完成：

- Dart 已认证冷启动调度、系统动作与 CallStateController/群通话控制器联动。
- CallKit 音频激活与 WebRTC 生命周期协调，连接成功才确认接听。
- 独立 VoIP token 登记、轮换/注销和服务端队列路由；未完成前不启用 bind。
- 真实 iPhone 锁屏、接听、拒绝、对方取消、超时、重复邀请及图标/声音验收。

参考：[Apple PushKit 来电处理](https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit)。
