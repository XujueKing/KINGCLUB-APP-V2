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

## 2026-08-28 用户局部复验

- 用户提供原版左上工具栏裁片，指出二维码与设置图标的大小和间距存在偏差。
- 原 `passed` 结论撤销。
- P1：旧实现使用固定 `29dp` 图标加 `13dp` 裸间隙，没有按旧版 `750rpx` 页面宽度换算，也未复刻两个独立 `80rpx` 点击区。
- 修正门禁：两图标统一按旧版 `40rpx` 显示，分别在 `80×42rpx` 点击区居中；中心间距恢复为图标宽度的 2 倍，并重新捕获 Android 同视口裁片。
- 2026-08-28 实机首轮复验进一步确认：`40rpx` 必须按 `页面宽度 / 750` 换算；393dp 视口为约 `21dp`，不能沿用固定 `29dp`。
- 整页文字已按旧源码重新标尺：昵称 `38rpx`、账号 `22rpx`、统计 `34/26rpx`、标签 `24rpx`、页签 `28/32rpx`；移除原实现多处 `w700/w800`。
- 新实机证据：[android_my_profile_typography_v2.png](screenshots/android_my_profile_typography_v2.png)，1080×2400 / Android API 37。
- 专项自动测试：`my_profile_toolbar_test.dart` 与 `my_profile_typography_test.dart`，2/2 通过；`flutter analyze` 0 问题。
- 头图信息关系已按旧源码重排：`540rpx` 面板分界、`400rpx` 头像顶部、`180rpx` 头像、`40rpx` 面板压盖，以及四个 `104rpx` 固定统计项。
- 新排版证据：[android_my_profile_header_layout_v2.png](screenshots/android_my_profile_header_layout_v2.png)，头像、身份文字、统计、编辑按钮和资产行均已进入同一旧版比例坐标系。
- 新增 `my_profile_header_layout_test.dart`；当前页面专项测试 3/3 通过。

final result: blocked
