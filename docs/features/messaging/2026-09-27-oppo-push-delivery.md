# OPPO 普通通知首条送达验收

范围：正式包 `com.lingmei.kingclub`，仅 A/B 测试会员中的 B；使用既有普通通知能力，没有申请 IM 分类。未卸载、清数据或操作第三台 USB 设备。

服务端凭据已从已登录开发者中心配置并保存在 Git 外的受限文件及服务器 root-only 配置。使用当前服务镜像的 OppoPushClient 鉴权成功，单独发送一条五分钟有效的通用消息通知，供应商返回 accepted。未输出或提交凭据、设备令牌、会员标识。

B 退到桌面并休眠后接收该通知。Android Notification Manager 的活动 Notification List 出现正式包通知，importance=3、mHidden=false、mIntercept=false；系统实际归入 `push_oplus_category_content`，不是仅凭供应商成功响应认定送达。

唤醒后展开通知栏并向下方通知滚动，真实 UI 显示应用名“KingClub V2 预览版”、标题“KINGCLUB”、正文“你收到了一条新消息”。点击该条通知后回到已登录应用，UI 显示“聊天”和已选中的“消息”标签，没有进入手机号/验证码页。

证据原始文件保留在隔离构建目录 build/push-check-scroll2.xml、push-open.xml；不提交包含其他应用通知或会员信息的截图、转储。

边界：这是单独调用供应商客户端的定向测试，常驻服务的推送 worker 仍关闭。尚未证明真实消息 outbox → worker → 供应商 → 通知 → 会话的完整链路，也未验证系统回收进程、锁屏新来电或锁屏界面展示。当前已通过的是后台普通通知送达、通知栏展示及点击恢复已登录聊天首页。

下一项：保留线上镜像、环境变量、端口和现有登录适配挂载，接入常驻 worker 后，以 A/B 新测试消息验证真实队列链路。整体聊天目标保持进行中。
