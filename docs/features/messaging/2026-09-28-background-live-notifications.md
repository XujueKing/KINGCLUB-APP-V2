# 后台存活期间原生通知

用户批准参照 Telegram 的组合路径：存活连接接收、本地通知、厂商兜底。本阶段保留 Android 应用进程存活时的加密 WebSocket，切前后台重建一次连接，清除旧前台推送抑制租约；后台不发送前台心跳。不是无限保活，也不通过假音频或滥用摄像头服务维持进程。

后台事件必须经过当前会话、服务端授权查询、免打扰/已读/本人发送过滤再展示。来电校验收件人、邀请状态和期限；通知点击复用既有账号隔离的 push-open 路由，绝不自动接听或启动采集。退出/换号撤销本地通知，迟到查询不得污染新会话。

Android 使用独立消息/来电渠道，通知有效期及会话稳定 tag；设置 showBadge 与未读 number，使支持标准通知角标的桌面可显示。数字或红点形态由桌面及用户设置控制，不承诺 OPPO 独立数字角标权限。

边界：系统挂起/杀进程仍需厂商推送。本地重复事件去重不等于跨厂商通知的严格去重，跨路径投递回执仍需完善；保持厂商兜底，不用后台 TCP 存活假定消息已显示。

## 2026-09-28 真机记录

- Dart analyze 通过；后台生命周期、消息过滤、加密实时协议、连接超时共 16 项测试通过。
- Android preview/profile APK 构建成功，A/B 覆盖安装；未卸载或清除数据。
- B 后台 A 发送测试消息：04:03 日志 authorized chat.changed、messageEligible=true、localShown=true；Android NotificationRecord 确認本地消息渠道 importance=4、showBanner=true、showBadge=true。
- 第一轮消息未生成本地通知，原因尚未定论；后续后台来电尝试也未取得通知发布证据。因此不将后台长期稳定接收、后台来电标记为验收通过。
- B 桌面全局为“数字”，本应用消息渠道 mSupportNumBadge=false，桌面未显示角标。用户明确要求保留数字，不修改全局圆点设置。标准 showBadge/setNumber 不等于 OPPO 数字角标适配完成。
- OPPO 数字角标需核实平台授权；EngageLab 官方接入文档说明需要申请权限，未开通时请求可能成功但角标不生效。当前未提交申请、未获得权限，不伪装为已支持。
  https://www.engagelab.com/zh_CN/docs/app-push/developer-guide/client-sdk-reference/android-sdk/manufacturer-channel-integration-guide
- 本地日志只记录事件类型、布尔结果和异常类型，不记录用户账号、消息正文、会话凭据。

待完成：首轮漏通知原因、后台来电/取消闭环、系统冻结后厂商到达、跨厂商去重、数字角标授权及未读计数/已读清零全链路。此提交是后台接收基础，不是完整 Telegram 等价实现。
