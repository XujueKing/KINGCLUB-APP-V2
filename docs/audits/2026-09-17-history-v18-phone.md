# A 手机历史数据库 v18 安装验证

主仓 dd42da5 的清理修复及 eef683d、bf08417 合入干净 preview，最终 de3e29d。Profile ARM64 构建成功，Gradle 66.0 秒，APK 159.3 MB。仅 A（462606d8）覆盖安装，adb 返回 Success，启动第一次前台验证通过。B 未操作。

安装前后应用停止状态下通过 run-as 读取本账号数据库到忽略的 build/v18-before、build/v18-after；只输出统计，不公开会员内容或密钥。安装前 user_version=17，安装后=18，两次 integrity_check 均 ok。message 均 89 行；按 conversation+sequence 对比缺失 0、密文变化 0。nearby_message 两次均 0，因此本机证据证明升级及普通消息保留，不能代替隐藏直连正文清理的数据库测试。未删除任何真实会员消息。

安装后实际打开消息栏目，UI 中聊天、通讯录及测试群 KINGCLUB-AB-0915-OK 存在。数据库取证后重新启动，前台验证通过。未证明主观动画验收、双端通知或头像刷新全部通过。

持久化删除仍保留此前范围限制：未发送队列取消尚未实现；公共相册/下载中主动导出的文件不属于待清理的应用缓存。
