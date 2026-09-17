# A 群聊历史离线冷启动

- A 当前安装 f376605 / Profile。打开 KINGCLUB-AB-0915-OK，资料页显示两位成员，A 为普通成员、另一成员为群主；本次不修改群资料、不发送消息、B 未操作。
- 保存在线可见历史后，确认 airplane_mode_on=1、wifi_on=0，强制停止 App，再启动进入消息列表和同一群聊。
- 在线与离线均有 5 个可见消息行，其语义描述集合完全一致，群标题保留。该范围证明实际群历史持久化后可在断网冷启动读取；不扩大为所有分页、全部媒体播放、头像图像或双端群收发验收。
- finally 恢复飞行模式/Wi-Fi/移动数据，随后读取 airplane_mode_on=0、wifi_on=1。UI 文件 build/kc-group-online.xml、kc-group-offline.xml 私有保留，不提交聊天正文。
