# Design QA — Profile Asset Pills Equal Height v9

- source visual truth: 用户当前会话提供的余额、金币、钻石与“我的订单”同排局部截图
- implementation screenshot: `audit/2026-08-29-equal-pills/01-equal-height-pills.png`
- viewport: Android emulator `1080 × 2400 px`，约 `432 × 960 dp`
- state: 我的主页 / 动态 Tab / 四个资产入口同排
- typography: 原有 14dp 字阶保留；“我的订单”继续以深色粗体强调，其他资产保持白色中等字重。
- spacing and layout: 四个胶囊统一固定为 `34dp` 高，水平内边距同为 `11dp`，取消各自纵向 Padding 推导；宽度仅随内容变化。
- colors: 三个资产入口保持半透明黑色，“我的订单”保持香槟金实底，未改变黑金主题。
- image quality: 金币、钻石使用原始旧版 PNG；订单图标继续使用现有 Material 图标。
- copy: `余额：¥ 0.00 / 50 / 0 / 我的订单` 保持不变。
- automated evidence: widget test directly measured all four keyed controls at `34.0dp`.
- findings: no actionable P0/P1/P2 mismatch remains in the requested row.

final result: passed

---

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

## 2026-08-29 “我的订单”入口专项验收

- 用户要求：在“我的”页面新增订单入口，点击进入现有订单中心。
- 视觉位置：跟随余额、金币、钻石资产胶囊同行，不覆盖头图、统计、标签和作品页签。
- 视觉规格：深色胶囊、香槟金订单图标、暖白文字，最小点击高度 `44dp`。
- 真机证据：[1080×2400 完整返回链路](audit/2026-08-29-orders-entry/04-back-to-my.png)。
- 交互结果：“我的 → 我的订单 → AA 订单详情 → 订单中心 → 我的”通路正常，返回后仍保持“我的”Tab。
- 工程校验：入口专项测试、App Shell 8 项流程测试均通过；`flutter analyze` 0 问题。

final result: passed

---

## 2026-08-29 内容页签箭头专项验收（已被 2026-08-30 规则替代）

- source visual truth：用户在当前会话提供的“动态选中”与“作品选中”局部截图。
- implementation screenshots：项目根目录 `.tmp-profile-tabs-dynamic-final.png`、`.tmp-profile-tabs-works-final.png`。
- viewport：Android 模拟器 `1080 × 2400 px`。
- 当日验收基线曾限定只有“动态”显示箭头；该行为已按用户 2026-08-30 的新确认废止。
- `test/app_smoke_test.dart` 已覆盖作品、动态、相册三次切换。

final result: passed

---

## 2026-08-30 内容页签箭头跟随规则

- source visual truth：用户要求三个页签采用一致的选中反馈，不再让箭头只属于“动态”。
- 作品、动态、相册仍为互斥选中；当前项加粗，并在文字右侧显示同尺寸小箭头。
- 任一状态仅允许出现一个箭头，箭头随点击移动，不单独获得点击区域。
- 自动化用例分别点击三个页签并校验箭头所属项和唯一性。

Android 同视口截图已覆盖三种选中状态，箭头位置、字号和间距一致，无 P0/P1/P2 偏差。

final result: passed
