# B 麦克风权限撤销与群席位回收

## 范围

B 使用 APK SHA256 `80BB4FE7D8986D28CD6F805B813AE16E5969E141A713F7B2052E307D10A7E60B`。仅在既有 A/B 两人测试群发起语音邀请；A 不在 USB 列表，未操作 A 或第三台设备，也没有伪称本次双向声音接通。

开始前 B 麦克风、摄像头均为 granted=true，USER_SET；私聊输入无草稿。群通话发起后，B 在服务端为 joined，A 为 invited 后自然 expired；B 页面显示“正在连接／已加入”，CallForegroundService 已运行且 isForeground=true。因 A 未接听，本次覆盖本地采集已启动后的撤权清理，不覆盖双向通话中的撤权体验。

## 实测

1. 设备拒绝 ADB pm revoke/grant，返回 shell 缺少运行时权限管理权限。确认没有改变权限，随后使用正常系统应用详情 → 权限管理 → 麦克风 → 不允许。没有修改系统安全限制。
2. 系统包状态确认 RECORD_AUDIO granted=false，原 App PID 不再存在，CallForegroundService 不再存在。此路径由 Android 结束进程，不能据此声称 Dart onEnded 被触发。
3. 服务端紧接查询仍有 B joined、occupied=1、剩余租期约 31.5 秒，符合进程消失后无法发送 leave 的情况。约 54 秒后的查询为 ended=true、occupied=0，A/B 均 expired；没有调用写数据库或手工清席位。
4. 通过同一系统页面恢复“使用时允许”。包状态确认麦克风与摄像头 granted=true、原 USER_SET 标志保留。重新打开 App 仍登录，群历史显示本次“群语音通话 · 通话已结束”，随后返回原私聊，既有文件和 UI 测试消息保留。

服务端核对只读限定测试群：确认唯一同名活跃群及两个成员，再读取本次最新通话、participant phase/deadline 和 occupancy 数量；不输出会员标识或会话凭据。此次发起者为 B，另一个成员为 A。

## 结论和边界

B 的系统撤销麦克风权限会结束进程，通话服务随之消失；服务端租期自动回收有效，没有永久占位。恢复权限和重启不丢登录及聊天历史。本次不证明群视频摄像头撤权、已建立双向音频的撤权、普通后台保活或锁屏新来电已通过。
