# 会话底部锚定与消息插入

用户反馈进入会话时从第一条滚到最后一条，发送和键盘跟随不平稳，并反馈时间不明显。

根因：正向 ListView 首屏处于顶部，数据到达后 animateTo(maxScrollExtent)，懒布局改变最大偏移后再 jumpTo，造成可见滚动和二次跳动。改为反向懒构建列表，以零偏移锚定最新消息；时间和消息仍按正常顺序显示，向旧记录末端滚动才触发 loadOlder。已有本地 SQLite 每页默认50条，网络也使用分页，不一次渲染全库。

新消息使用220ms高度展开，历史分页不播放插入动画；真实消息按稳定ID映射索引，避免新消息加入后旧行状态全部重建。键盘/附件面板尺寸变化时保持最新端零偏移，移除滚动末尾额外jumpTo。时间继续按首条、跨天和五分钟间隔显示，提升标签不透明度；未伪造缺失时间。

参考：https://docs.flutter.dev/cookbook/lists/long-lists 及 https://pub.dev/documentation/flutter_chat_ui/latest/flutter_chat_ui/ChatAnimatedList-class.html 。参考滚动与插入职责，不引入整套UI库或覆盖已确认样式。

尚未安装本次滚动改动到手机，不能把组件验证当成真机帧率、键盘动画同步已验收。持续上翻后的内存窗口裁剪尚未新增，不宣称内存无限恒定。
