# J01 冷启动与会员准入真机验收

- 日期：2026-08-29
- 设备：Android 1080×2400 USB 真机
- 构建：Flutter `preview` Debug，初始路由 `/auth/bootstrap`
- 数据：本地 UI Mock，未连接真实短信、超级接口、WebSocket 或会员审核服务

## 通过链路

`Welcome → 手机号/验证码 → 实名成年核验 → 会员形象 → 风格音乐 → 酒类活动 → 审核中 → 已通过 → Shell 首页`

## 证据

1. [旧版欢迎页](01-welcome.png)
2. [手机号登录页](02-login.png)
3. [步骤 1：实名成年核验](03-adult-check.png)
4. [步骤 2：会员形象资料](04-profile-images.png)
5. [步骤 3：风格与音乐](05-style-music.png)
6. [步骤 4：酒类与活动](06-drink-event.png)
7. [审核中](07-review-pending.png)
8. [审核通过](08-review-approved.png)
9. [进入 Shell 首页](09-shell-home.png)

## 结论

- 真机成功主链可完整执行，导航未出现空栈、黑屏或路由丢失。
- 审核中不提前放行；只有本地场景切换为“已通过”后才显示“进入 KingClub”。
- 专项 Widget 测试 `mock sms and onboarding flow reaches the app shell` 通过。

final result: passed
