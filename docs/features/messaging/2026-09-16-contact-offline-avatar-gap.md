# A 通讯录断网重启验收及头像缺口

2026-09-16 06:12，A 使用包含 3324ae0 的 Profile/LAN 包。联网进入通讯录，名单包含两个已有联系人，均显示真人头像。关闭网络、强制结束进程、冷启动后进入通讯录；Android `Active default network: none`。

结果：两个联系人、性别及字母分组仍显示，并有网络不可用提示；但两个真人头像均退回默认头像。因此名单离线恢复通过，头像离线恢复不通过。未编辑或发送消息给联系人，B 未操作。

定位：`ChatMemberAvatar` 仅在 profile Future 成功后取得 avatar.fileId，再交给 `CachedMediaImage`。`cachedChatAvatarProfile` 只有进程内缓存；断网重启后资料请求失败，无法取得本机图片的内容键。联系人加密快照只保存 peer/nickname/remark/bio/gender。因此不能仅凭已有图片磁盘缓存宣称头像可以离线显示。

修复要求：按当前登录账号持久保存最小头像文件标识；仅明确网络失败时读取已缓存图片，不缓存鉴权 headers、令牌或签名 URL，不将旧快照当成在线媒体授权。明确权限拒绝、头像移除、账号切换应清除或禁止旧图；迟到请求不得污染新账号。完成后重做本次真机步骤。

网络已恢复，Wi-Fi、移动数据设置均为 1，默认网络 123。私有截图及 XML 位于 build/phone-a-contacts-online/offline.*，不提交。本节点记录真实失败证据，尚未修复该缺口。
