# Design QA — Legacy Add Friend Replica v1

- 来源：旧版 `pages/addfriend` 与用户确认的通讯录双入口。
- 实机证据：[android_add_friend_latest.png](android_add_friend_latest.png)
- 环境：Android API 37，1080×2400。

## 结果

- 顶部返回和居中 `添加朋友`、扫一扫菜单、说明、右箭头及大号二维码保持旧版结构。
- 旧版永久账号二维码替换为不可解析的 Fake 视觉二维码；页面明确标注不含真实账号凭证。
- 扫一扫已验证可进入现有安全扫码 UI，并能返回本页。
- `flutter analyze` 0 问题；`flutter test` 11/11。

final result: passed
