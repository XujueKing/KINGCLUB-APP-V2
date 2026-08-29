# Auth/Onboarding 返回栈实体机验收（2026-08-29）

## 环境

- 设备：Xiaomi 14 Pro（1080×2400）
- 包名：`com.lingmei.kingclub.v2preview`
- 构建：Flutter Preview Debug，正常 `/auth/bootstrap` 启动
- 数据：本地 UI Mock；没有连接真实登录、短信、超级接口或 WebSocket

## 缺陷与根因

- 修复前，auth/onboarding 页面通过 `go()` 建立受控替换目标，但 Android 系统返回仍会直接尝试 pop 当前唯一 Router 页面。
- 页面左上角返回键能执行批准的目标，系统返回却绕过该回调，因此可能只剩 Flutter 黑色画布和系统栏。

## 修复

- Router 层统一使用受控 `PopScope` 拦截 bootstrap、welcome、mobile、SMS 和 onboarding 替换页。
- 步骤页系统返回执行与可见返回键相同的 RouteData 目标。
- bootstrap 禁止 pop；welcome/review 根页执行平台根页退出语义，不允许弹空 Router。
- 页面视觉和 Fake 业务状态未改变。

## 实体机证据

1. `01-identity-before-back.png`：实名与成年核验页，修复后测试起点，健康。
2. `02-system-back-to-login.png`：按一次 Android 系统返回后稳定进入手机号登录页，健康。
3. `03-system-back-to-welcome.png`：再次按系统返回后稳定进入旧版封面页，健康。

连续返回过程中没有出现空 Router、黑屏、默认错误页或 Flutter 崩溃。

## 自动化

- 新增 `system back never empties the auth onboarding router` Widget/Router 回归用例。
- `test/app_smoke_test.dart`：37/37 通过。
- `flutter analyze lib/src/navigation/app_router.dart test/app_smoke_test.dart`：无问题。

## 限制

- 本轮验证 Android 实体机；iOS 交互返回仍需未来 macOS/Xcode 环境补测。
- 本轮没有启用真实 Session、登录 Flow 恢复或生产 SDK。
