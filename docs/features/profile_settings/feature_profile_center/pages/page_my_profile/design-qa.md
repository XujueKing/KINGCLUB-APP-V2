# Design QA — Legacy My Profile Replica v1

- 视觉真值：用户于 2026-08-26 提供的旧版“我的”完整首屏截图（580×1200，含设备框）
- 实现证据：[android_my_profile_latest.png](android_my_profile_latest.png)
- 实现像素：1080×2400；Android API 37 模拟器
- 状态：App Shell / “我的”选中 / 动态选中 / 头像为空

## 对照结论

- 复刻了夜景封面、左上二维码与设置、独立 EXP、头像压住面板、昵称等级账号、四项统计、编辑主页、三项资产、六个标签、三项内容页签与旧版底栏。
- 用户要求的头像留白已执行；没有使用参考图中的真人头像。
- 微信小程序宿主胶囊按已确认规则排除，App 中只保留独立 EXP。
- 动态内容区按参考截图保持空白；作品与相册可切换但不伪造用户媒体。
- Android 平台状态栏与旧版 iPhone/微信容器不同，属于平台外壳差异。

## 交互核对

- 自动测试覆盖空头像、全部可见文案、三页签切换、个人二维码和设置入口。
- 模拟器语义树核对了二维码 Fake 凭证说明及设置内支付安全、注销、退出登录等条目。
- 编辑、统计、资产和 EXP 均为可返回本地面板，不访问服务端。

## 工程核对

- `flutter analyze`：通过，0 问题。
- `flutter test`：通过，10/10。
- 图片资源：旧版图标直接复用；上海夜景由内置 ImageGen 根据用户截图生成并保存为 `assets/legacy/profile/my_profile_skyline_v1.png`。

final result: passed
