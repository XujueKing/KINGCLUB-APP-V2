# J07 私人储物柜与动态取件凭证审计

- 日期：2026-08-29
- 设备：小米 `23116PN5BC`，Android USB 真机，1080 × 2400 截图
- 构建：`previewDebug`，入口 `/home`
- 数据边界：仅本地 Fake 状态；未连接真实储物、核销、WebSocket 或生产接口
- 结论：J07 主链和规定异常状态通过，可进入全局 UI Mock 收口检查

## 本轮发现与修复

1. 文档要求的过期、重放拒绝、核验结果未知缺少可重复 UI 状态；已补齐，并保证这些状态不显示可扫描图案。
2. 私人储物柜独立挂载时缺少 Material 承载层；已修复分类和空柜说明按钮的点击与布局基础。
3. 部分交付状态在后台恢复或自动换码后曾错误恢复为 65%；已将“换凭证世代”和“重置业务状态”分离，恢复后仍保持 35% 部分交付。

## 真机证据

- [01-storage.png](01-storage.png)：旧版空储物柜首屏与固定页签。
- [02-empty-sheet.png](02-empty-sheet.png)：空柜正式文案及取件凭证入口。
- [03-ready.png](03-ready.png)：正常动态凭证、倒计时和物品信息。
- [04-expired.png](04-expired.png)：凭证过期且不显示可扫描图案。
- [05-replay.png](05-replay.png)：重放拒绝且剩余量不变。
- [06-unknown.png](06-unknown.png)：结果未知时不误报交付成功。
- [09-final-partial.png](09-final-partial.png)：最终包部分交付状态为 35%。
- [10-final-background.png](10-final-background.png)：系统最近任务卡片中的凭证已遮盖。
- [11-final-resume.png](11-final-resume.png)：回前台签发新世代后仍保持 35% 部分交付。
- [12-return-storage.png](12-return-storage.png)：返回后仍停留私人储物柜页签。

上述作为验收证据的截图均在本轮生成并逐张目视检查。XML 仅用于确认可访问节点和返回路径，不代替视觉判断。

## 自动化与静态检查

- `flutter test test/private_storage_flow_test.dart test/app_shell_flow_test.dart`：16 项通过。
- 覆盖正常轮换、部分交付、已取出、暂停、离线、过期、重放拒绝、结果未知、后台遮盖、前台新世代、空柜入口和返回路径。
- `flutter test`：全项目 284 项回归全部通过。
- `flutter analyze`：0 问题。
- `flutter build apk --debug --flavor preview --dart-define=KINGCLUB_INITIAL_LOCATION=/home`：成功。

## 审计边界

- 当前二维码是视觉占位，不承载真实凭证载荷。
- 真正的签名、过期校验、原子核销和服务端重放拒绝仍须在 UI Flow Approved 后按已批准契约接入并重新做安全验收。
- 截图不能单独证明完整无障碍质量；本轮仅结合语义树和自动化覆盖关键入口与状态。
