# 群聊清空记录入口

发现现有群消息 settings 接口已提供 hide，但群详情只有退出/解散入口。新增独立“清空聊天记录”和二次确认，不触发退出、解散或删除其他成员数据。

复用 K260913000623 的 `{groupId, hide:true}`；核对后端 group-messages.ts：成员事务更新本人的 hiddenThrough/readSequence，并只向本人写入 chat.group.read outbox，返回 saved=true。没有新增接口、迁移或改变群成员关系。

客户端必须收到 saved=true 才执行本地清理回调，返回值 false 表示未离群。DirectChatPage 回调仅在原 repository 仍属当前会话时调用 resetVisibleHistory(clearMedia:true)，复用已有加密历史清除、媒体引用保留、下载块清理和同步屏障；随后按服务端可见边界同步。待确认、过期权限、背景或登录变化均阻止继续提交；失败留页可重试。已发出的服务端事务不冒称可以撤销。

新增四项真实组件测试：确认成功只发送 hide 且返回未离群、saved=false 不触发清理或退页、取消不写、确认期间换登录不写。四项通过；既有群设置及媒体/共享引用清理 15 项通过。第一次组件测试因滚动后未等待布局导致点击落在屏外，补齐 pumpAndSettle 后四项通过，未绕过实际按钮点击。修改文件 analyze 通过。

本轮没有清空 A/B 真实记录；此入口和私聊设置确认修正待下一批集中安装与实机验收，不将自动化覆盖登记为真实数据清空验收。
