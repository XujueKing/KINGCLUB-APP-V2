# A 删除转发视频与磁盘清理

预览 26ad5be，A/B 会话，仅操作 A。删除对象是前轮已授权发送/转发的 8 秒合成测试视频中较新的转发卡片。通过长按→为我删除→确认删除完成，无 adb 文件删除。

界面由两个 8 秒卡片变为一个。对比应用私有 files/media-store-v1 文件清单：移除一个 MP4（78467ad9635e179ea15ca3331acf8509087895dfbc42725aa8b17087b52e3781）和两个图片缓存（988ef387a0878cc7d1379b734e40c109f8751e7f05bac0ecfc3e175e11b95e0e、4878bac061dd4249c63f3ed52e37d2f8764fae4dd4023323a53dce6edbb10183），增加九个删除屏障标记。

关闭网络并确认默认网络 none，强制停止后冷启动，重新进入会话：remaining_video_cards=1，deleted_files_restored=0。Download 原始合成视频仍为 20,071,696 字节。随后恢复 Wi-Fi/移动数据。清单保存在预览 build/video-delete-before.txt、video-delete-after.txt、video-delete-offline.txt，不提交私人目录清单。

仅证明这一条转发视频在 A 上的删除、对应磁盘缓存清理和离线冷启动不恢复。未操作 B，不代表撤回对方记录，不覆盖清空全会话、未发送队列或原生播放器正在播放时删除。
