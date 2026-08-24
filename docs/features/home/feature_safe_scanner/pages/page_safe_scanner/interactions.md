# 扫码页交互

## 打开与权限

- Shell/首页点击经过 300ms 去重，只建立一个 overlay。
- 首次显示用途说明；用户点击后请求权限。已授权时以后可直接进入相机 active。
- 永久拒绝时“打开设置”通过 `NativeSettingsPort` Fake；返回后重新查询，不假设成功。

## 捕获与解析

- CameraPort 首次给出合格 payload 后立即暂停；后续 frame 被忽略。
- 解析按钮/回调使用 SingleFlight；手动“重试解析”复用仍在 TTL 内的内存 attempt。
- “重新扫码”销毁旧 attempt，恢复相机并创建新 attemptId。
- 成功只发出一次类型化 RouteIntent；NavigationCoordinator 接管后 scanner 不再持有引用。

## 返回与生命周期

- 关闭、系统返回、手势返回均回到 `OriginBranchRef`；原分支状态不变。
- 解析中返回立即停止预览、关闭补光灯并标记 generation 失效。
- 进后台暂停相机；回前台复核 session、会员、权限后恢复。
- 页面销毁后迟到权限或 resolver 回调不得弹 Toast、恢复相机或导航。

## 无障碍与反馈

- 权限说明、识别中、成功类别和失败原因使用 live region/语义播报。
- 扫码框、颜色和震动都不是唯一反馈；减少动态效果时关闭扫描线动画。
- 补光灯控件朗读当前开/关状态，触控目标至少 48×48dp。
- 错误动作顺序固定为主动作“重新扫码/重试”，次动作“返回”。
