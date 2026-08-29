# KC-P-036 Android 真机验收

- 日期：2026-08-29
- 设备：Xiaomi 14 Pro（`23116PN5BC`，arm64-v8a）
- 分辨率：1080 × 2400
- 构建：Flutter preview debug，Fake/Mock 数据
- 入口：`OrderCenterRoute` / `/commerce/orders`

## 验收路径

1. 核对全部订单混排与四个状态筛选。
2. 切换待支付，确认只保留对应状态族。
3. 打开订单详情，确认列表只传递不透明 `OrderRef`。
4. 加载第二页，确认新增订单不重复并显示到底提示。
5. 验证首屏失败重试、全部为空、离线缓存、未知状态和会话失效设计。

## 证据

- [默认混合列表](order_center_default.png)
- [待支付筛选](order_center_pending.png)
- [分页到底](order_center_pagination.png)
- [订单详情交接](order_center_detail_handoff.png)
- [首屏失败](order_center_error.png)
- [全部为空](order_center_empty.png)
- [验收场景切换器](order_center_scenarios.png)

## 结果

- 页面无溢出、底部碰撞或不可见主入口。
- 正常用户路径未出现 `Fake`、`Mock`、内部订单引用或测试说明。
- 专项 Widget 测试 10/10 通过，`flutter analyze` 无问题。
- 旧版不存在统一订单中心运行页面，因此本轮确认已批准的旧版结构组合和交互完整性，不声明逐像素复刻。

结果：KC-P-036 在 UI/Fake 范围内通过 Android 真机验收；真实订单、WebSocket 和支付接入继续保持阻断。
