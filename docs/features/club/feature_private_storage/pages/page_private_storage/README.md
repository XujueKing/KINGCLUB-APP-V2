# 私人储物柜页

- Scope ID：`KC-P-047`
- 文档状态：`Approved for Development`
- 批准日期：2026-08-26
- 所属功能：[私人储物柜](../../README.md)
- 页面位置：`AppShellPage` 第 4 个底部页签（私人储物柜）；当前不注册独立 GoRouter 路由
- 设计版本：`Private Storage Wireframe v1 / List / Legacy Private Storage Replica v1`

## 当前复刻决策

- 用户于 2026-08-26 提供旧版完整截图，确认下一批开发私人储物柜板块。
- 当前首屏以 [旧版私人储物柜 UI 复刻规范](legacy_ui_replication.md) 为准；原列表线框保留为后续有内容状态和详情信息架构参考。
- 本轮只复刻截图中的空储物格状态及本地 Fake 交互，不连接真实储物、取件码或员工核销能力。
- UI 状态：`Implemented & Device Verified`（2026-08-26，离线 Mock）；验收截图见 [android_private_storage_latest.png](android_private_storage_latest.png)。
- 2026-08-29 路由复核：页面实际由 App Shell 的 `IndexedStack` 承载，文档中原 `/me/storage` 独立路由描述已纠正。

```text
[返回] 私人储物柜
[存酒] [物品]
[图片] 名称 · 可取/临期/已过期
数量/剩余量 · 存入/到期时间       [查看]
```

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
