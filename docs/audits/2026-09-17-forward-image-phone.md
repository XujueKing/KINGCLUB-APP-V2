# A 转发图片离线真机验收

设备 A，预览 e3a30ec。在 A/B 授权会话通过原生文件选择器选择项目素材 KINGCLUB-retention-test.png（wine_flip.png），发送后长按该图转发给 B 并确认。未操作 B，未转发用户私人图片。

禁用 Wi-Fi/移动数据，确认 Active default network: none 后强制停止并冷启动。进入原会话，等待路由动画结束，截图确认原图和转发图缩略图均显示项目素材。点击较新的转发图，大图正常显示；此时再次确认默认网络仍为 none。随后恢复 Wi-Fi/移动数据并返回会话。

本地截图位于预览工作树 build/kc-img-offstable.png 和 kc-img-full.png，不提交聊天内容。首次进入时截到路由动画中的 kc-img-offline.png 不作为稳定布局证据。

本次仅验证 A 发送方的 PNG 转发后离线冷启动显示；不证明 B 收取、群聊、动态图、转发视频或语音播放完成。
