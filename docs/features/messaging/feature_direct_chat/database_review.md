# 单聊与关注关系数据库审查

状态：Model In Review，2026-09-13。用户授权持续开发及隔离联调；本文件未将尚未核完的旧接口分类、Routine 依赖标为完成。未执行聊天数据库迁移。

## 用户动作及最新边界

关注为单向关系，互相关注推导好友。发送第一条私信需要关注，未获对方回复前只允许一条；回复者不必先关注，双方已有实际发送后可以继续聊。拉黑优先。普通聊天免费，发送和重试不扣经验/资产。头像跳转旧版抖音式主页，资料权限与聊天权限分别校验。群聊、礼物和付款的独立事务审查不在本单聊切片冒充完成。

## 已核对旧调用链

| 动作 | 已核对源代码与对象 | 一致性及副作用 |
|---|---|---|
| 发送 | 小程序 pages/chat/chat.js sendMessage2 → /msgPush → web-rest KingClubApi → service-business-service KingClubService.msgPush:1108 → superService.process(S231202503110662) → K_SendMessage | Java 检查双层 sessionToken、一致 userAccount、会话成员，并从服务端重算收件人；SQL 已有事务、异常处理和回滚，不能误写成无事务。保存后 RunnablePushThreadList 异步推送，返回服务端 messageId |
| 历史 | 小程序 S231202503110661 → K_GetMessageListByConversationsId | 旧查询同时更新已读、groupReadUsers；新版历史读取与显式已读确认分开 |
| 头像 | pages/chat/chat.js:833 → pages/userInfo/userInfo → S231202506270743 | 背景、头像、账号、签名、关注/粉丝、标签、作品/动态；不将实名证件、手机号等私有列投影给任意访客 |
| 关注 | pages/userInfo/userInfo.js followTap → S231202506290744 | 新版互关即好友覆盖旧版独立朋友私聊申请；旧 Routine 和表依赖仍待完整提取 |

待补证据：四个接口的 s_interface.interfaceType → s_interface_type 父链；推送线程落表；关注 Routine、触发器/事件递归依赖。未完成前不宣称 Inventory Complete。

## 已核对旧数据结构及目标去向

| 旧对象 | 字段语义 | 新版方向 |
|---|---|---|
| k_conversations | conversationsId 唯一；type 0 单聊/1 群；memberIds CSV；群主、公告、管理员 CSV | 新建单聊规范账号对唯一键；群成员另表，暂不导入旧会话 |
| k_conversations_messages | messageId 唯一；senderId、content、type、parentId；messageStaus、groupReadUsers CSV；日期、deleted | 稳定客户端幂等 ID、服务端消息 ID、会话递增序号；(conversationId,sequence) 历史索引；按成员记录已读游标 |
| k_conversations_messages_reads | messageId、userAccount、readId | 单聊游标，区分服务端持久化/设备收到/用户已读 |
| k_conversations_messages_attachments | fileUrl、fileType、fileSize 字符串 | 媒体切片独立审查；附件用授权文件 ID，不传本机绝对路径 |
| k_conversations_blacklist | blockedUserAccount CSV | 双账号规范行，任一方向拉黑拒绝新消息 |
| k_user_setup | 备注等用户设置 | 按本人+对方隔离，不改变对方公开昵称 |
| k_user | 昵称头像、经验等 | 新版 kingclubMember/Profile 只读投影；不导入旧会员 |
| k_conversations_group_temp、k_goldcoin_detail、k_config | 历史 Routine 混合返回群申请、金币及配置 | 从单聊纯历史返回拆出；不在本切片授予资产/群操作 |

K_SendMessage 递归调用 getGenerateId、get_display_chat_time、k_setCount_Exp。用户明确批准取消普通聊天的经验扣减，后者不迁移到发送事务；公共身份、资产函数不因被引用自动迁移。旧消息类型 0 文本、1 图片、2 文件、3 音频、4 视频、5 金币、6 红包、7 AA、8 礼物、9 群房间，不用其数值表达已送达状态。

## 新版事务契约（实施中）

1. 从加密 session 得到 actor，严格拒绝客户端 sender 字段。检查注册/账号有效性。
2. 锁定规范账号对；关注、拉黑、发送共用该锁，禁止两台设备各读到剩余一条。
3. UNIQUE(sender,clientMessageId)；相同 ID/相同正文返回原确认，不重复插入和通知；不同正文或收件人拒绝冲突。
4. 从持久发送证据、有效双向关注和拉黑计算许可。已读、删除本地会话、撤回、取消后再关注不能重置发送证据。媒体将共用同一许可，不按类型各给一条。
5. 在同一事务内插入消息、更新序号及双方发送证据、写持久通知 outbox；提交后通知，仅 WebSocket 成功不代表消息持久化。失败回滚，重试不能扣经验。
6. 关系设置、未读、草稿按登录账号隔离；旧会话数据不 ETL。回滚关闭新接口，保留已收新消息以免丢失，不能直接删表回退。

保留与删除：本人删除会话为可见性/游标操作，不删除对方副本，也不重置私信额度；账号注销与法定保留流程单独评审。消息正文/公开资料仍为敏感数据，日志不打印正文、真实账号或媒体令牌。

当前验证：服务端纯许可与串行事务模拟测试覆盖并发邀请、幂等、回复、拉黑及输入伪造。尚不代表 MySQL 并发、故障回滚、超级接口权限、真机两端已通过。
