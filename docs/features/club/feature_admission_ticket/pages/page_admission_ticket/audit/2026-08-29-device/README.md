# KC-P-033 Android 真机验收

- 日期：2026-08-29
- 设备：Xiaomi 14 Pro（`23116PN5BC`，arm64-v8a）
- 构建：Flutter preview debug，Fake/Mock 数据
- 入口：`AdmissionTicketRoute` / `/club/admission`

## 验收路径

1. 可入场状态展示动态二维码、倒计时、场次和安全说明。
2. 已入场状态隐藏二维码并展示旧版斜置印章。
3. 有效离场上下文先展示确认按钮，再进行二次确认。
4. 已离场状态保持无码；主动点击后才生成新的再次入场码。
5. 离线状态不生成备用码，提供工作人员协助。
6. 隐私保护状态遮盖二维码敏感区域。

## 证据

- [01-ready.png](01-ready.png)
- [02-checked-in.png](02-checked-in.png)
- [03-exit-context.png](03-exit-context.png)
- [04-exit-confirmation.png](04-exit-confirmation.png)
- [05-checked-out-reentry.png](05-checked-out-reentry.png)
- [06-reentry-code.png](06-reentry-code.png)
- [07-offline.png](07-offline.png)
- [08-privacy-covered.png](08-privacy-covered.png)

## 发现与修复

- 初次验收发现“已离场 / 可再次入场”状态在用户点击前提前显示二维码，与动作文案矛盾。
- 已修正为默认无码，只有点击“生成新的再次入场码”后才签发并展示新码；专项回归测试已覆盖。

结果：主要状态、离场/再次入场路径和安全降级通过；未发现布局溢出、裁切或不可点击问题。

说明：旧版 `ticket` 只有 WXML/WXSS 源码，没有同状态运行截图，因此本轮确认结构、视觉语言和交互范围，不声明逐像素一致。
