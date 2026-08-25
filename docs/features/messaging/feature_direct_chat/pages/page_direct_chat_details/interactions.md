# 单聊详情页交互

- 免打扰/置顶以命名 patch、expectedVersion 和幂等键更新，失败恢复权威值。
- 点击用户发出 `openUserProfile(peerRef)`；点击关系权限发出 `openRelationshipPermissions(peerRef)`。
- 搜索 query 去首尾空白后 1～80 字，300ms 防抖，按 cursor 分页；正文不进入搜索日志。
- 清空前二次确认，命令结果未知时查询 clear cursor，不重复清空。
- clear 成功返回单聊空态；退出搜索恢复此前滚动位置。
- 关系结束时不能通过设置页重新开启消息权限。
