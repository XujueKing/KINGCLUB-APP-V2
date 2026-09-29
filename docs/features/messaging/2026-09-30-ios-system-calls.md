## 当前进度（本轮追加）

私聊已接入应用级 SystemCallRuntime：冷启动读取原生动作，按明确 callId 通过已认证接口
校验接收者、状态及中继租约，复用现有控制器；前台页面与后台共用一个媒体会话。
重复事件合并、注销/超时中止未完成准备，拒绝可打断接听等待。页面接听先请求
CallKit transaction，避免应用内接听后系统仍持续响铃。

独立 PushKit token 使用 apns_voip / apns_voip_sandbox 登记，按通道注销不删除普通
通知绑定。客户端通过 KINGCLUB_IOS_SYSTEM_CALLS 构建开关启用；默认关闭，待服务端
203 migration 部署后才构建启用版。群来电尚未接入系统控制器，继续原通知路径。

登录凭据及续期依赖的设备标识改为 iOS AfterFirstUnlockThisDeviceOnly，旧凭据通过精确 Keychain 查询
原位更新保护级别，不删除/重建、不传出凭据。设备重启后首次解锁前仍不可读。

验证：59 项客户端定向测试、analyze 通过。上一轮云编译 36599446724 发现 WebRTC
Swift 音频 API 要求 Category/Mode 枚举；已修正，本轮云编译 36602252220 通过。
尚未覆盖安装启用版、未证明真实锁屏来电/铃声/震动/KING 图标通过。

测试服务器 203 已执行，私聊 PushKit 队列代码已部署并通过运行时健康检查，保留旧
容器和部署前数据库备份。签名工作流新增可选 system_calls 参数，默认关闭。
本轮随后接入 KING 原图的原生 Alpha 模板生成（40pt、3x），不替换品牌字形；
该图标增量随签名包编译和真机检查，当前不能称图标问题已验收。

签名包 36603179626 编译、签名及完整性验证通过；安装前复核发现设备标识的锁屏
读取也需迁移，已补齐，保持原设备 ID 不生成新值。补充两个原位迁移测试，连同
登录恢复/续期/撤销相关 35 项检查及 analyze 通过；需构建包含此修复的新包再安装。

以下保留前序开发记录，状态以上述最新进度为准。

# iOS 系统来电接入（进行中）

用户明确要求 PushKit/CallKit、持续来电、系统接听/拒绝，并修复铃声、震动和
KING 图标；普通 APNs 横幅送达不算通话验收。当前阶段尚未达到真机验收。

原生入口 `AppleSystemCalls.swift` 在 App 启动早期创建 CXProvider，并通过
`kingclub/system-calls` 接到 Flutter。VoIP 注册必须显式 bind 已认证账号；
当前尚未在 Dart 运行时调用 bind，因此不会向未完成的通话流程投递真实来电。
已有普通 APNs 和通话后台音频继续保持原路径。

Flutter 通道封装 `native_system_calls.dart` 已加入，校验事件/动作 ID、账号与
范围，分开事件确认和系统动作完成。定向 analyze 无问题，3 项测试通过，覆盖
非法事件拒绝、UUID 大小写与原生 action 身份保留、确认事件不等于接听成功。
原生邀请报告完成与快速接听竞态已处理，已接听后不会重新启动未接听超时器。
原生入口版本 ddbb3df8 的 macOS 无签名编译 36597796348 已通过，系统来电整体仍未启用/验收。

后续增量：已打开的 iOS 私聊通话页连接 `SystemCallControllerBinding`，复用
原 CallStateController。接听等待实际 ICE 连接才完成系统 action；拒绝不会打开
麦克风，挂断可打断接听等待，远端结束同步关闭系统来电。CallKit 音频激活/
停用转交 WebRTC，手动音频模式仅由系统接听阶段持有并在结束后恢复。
本批定向 analyze 通过，状态机/通道 18 项和页面/呈现 8 项测试通过。
这不是冷启动后台接听完成：app.dart 仍未 bind，尚需全局调度及群来电接线。

VoIP 格式与服务端 `kingclub_call` 对齐：version、callId、recipient、scope、
video、expiresAt；不传姓名、群名、聊天内容。每次 PushKit 到达先报告系统来电，
随后处理失效/账号不匹配/重复/忙线。Flutter 尚未启动时保留事件；接听与拒绝
保留原生 action，待业务确认后 fulfill，失败或超时结束系统界面。
邀请截止后停止系统来电，注册账号改变时结束原账号所有来电。

本批使用系统默认铃声与系统触感策略；尚未完成自定义 KING 单色来电图标，
不能称铃声/震动问题已修复。系统静音、专注模式等仍由 iOS 控制。

还需完成：

- Dart 已认证冷启动调度与群通话控制器联动；目前仅已打开的私聊页接线。
- CallKit 音频接管的最新增量需苹果编译及实机验证。
- 独立 VoIP token 登记、轮换/注销和服务端队列路由；未完成前不启用 bind。
- 真实 iPhone 锁屏、接听、拒绝、对方取消、超时、重复邀请及图标/声音验收。

参考：[Apple PushKit 来电处理](https://developer.apple.com/documentation/pushkit/responding-to-voip-notifications-from-pushkit)。
