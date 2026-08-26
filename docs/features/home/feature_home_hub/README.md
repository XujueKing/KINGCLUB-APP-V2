# 首页聚合

- Scope ID：`KC-F-012`
- 文档状态：`Approved for Development`
- 所属业务域：`home`
- M0 范围：`In Release Scope`
- 设计版本：`Legacy Home Replica v1 / Component Content v1`
- 最后更新：2026-08-26

## 目标与用户价值

让已登录且会员准入通过的普通会员，先在 Flutter App 中获得与旧微信小程序一致的首页视觉和主要 Mock 交互；完成复刻验收后，再单独评审首页的信息架构升级。

## 已确认事实

- 旧 `pages/index/index` 同时承载首页、聊天、通讯录、内容、储物柜和我的，`index.js` 约 10 万字节，不能整体迁移。
- 旧首页展示昵称、等级、金币/钻石、广告、AA、VIP、扫码和图文/视频瀑布流；底部栏目还由服务端 `tabData` 动态控制。
- 历史 App Shell v1 曾采用四个固定主目的地和中央扫码；用户已在 2026-08-26 否决该映射，当前复刻固定为首页、消息与通讯录、内容、私人储物柜、我的五个目的地。
- KC-P-027～033 分别拥有 AA、VIP 和入场页面；KC-P-012 负责扫码安全分流。

## 当前实施顺序

### 已确认事实

- 用户于 2026-08-26 明确要求先复刻旧版 UI，后续再改版。
- 仍必须先完成并批准页面文档，随后才允许修改 UI 代码。
- 真实接口与 SDK 接入继续受项目级门禁阻断。

### 当前建议

视觉复刻旧版的会员资产头部、Banner、三联入口、运营海报瀑布流和悬浮胶囊底栏；工程结构仍保持 V2 分域、固定类型化导航和 Fake Runtime，不复刻旧版超大页面耦合。

## 页面

- [KC-P-011 首页](pages/page_home/README.md) — `Approved for Development`
- [旧版首页 UI 复刻规范](pages/page_home/legacy_ui_replication.md) — `Approved for Development`
- [首页组件内容复刻总表](pages/page_home/components/README.md) — `Approved for Development`

## 配套文档

- [旧版审计与取舍](legacy_audit.md)
- [用户流程与导航](flow_and_navigation.md)
- [数据、Repository 与 Fake 契约](data_and_api.md)
- [Mock/Fake 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 复刻阶段不包含

- 把聊天、通讯录、储物柜或完整个人资料重新嵌入首页物理页面。
- 服务端动态下发 Tab、Widget 类型、任意页面路径或任意 URL。
- 首页内直接下单、付款、核销、签到或确认入场。
- 新增门店列表、活动专题详情、全局搜索或通知中心页面。
- 真实首页接口、旧超级接口、WebSocket、支付、推送或生产 SDK。

## 已确认决策

用户于 2026-08-25 回复“按建议确认”，批准以下方案：

1. 首页采用“品牌头部 + 四个核心入口 + 今晚行程 + 精选活动 + 服务提示”的 v1 结构。
2. 首页不再展示金币、钻石、等级进度和内容瀑布流；它们分别归我的/钱包和发现页。
3. 首页与底部中央按钮都可打开安全扫码，两个入口行为完全一致。
4. 精选活动只允许无动作、打开本期批准页面或切换主 Tab，不打开外部网页。
5. 首页不主动申请定位；当前门店/城市使用账号默认值或服务端已保存选择，门店切换后续另行评审。

以上 `Home Hub v1` 是历史设计结论。用户于 2026-08-26 调整实施顺序：当前先做 `Legacy Home Replica v1`，历史新版方案留待复刻验收后重新评审，不再驱动当前 UI 实现。

## 开发门禁

用户已于 2026-08-26 确认 [旧版首页 UI 复刻规范](pages/page_home/legacy_ui_replication.md)、旧版五 Tab 语义和 [首页组件内容复刻总表](pages/page_home/components/README.md)，当前恢复 UI/Mock 开发；项目达到 `UI Flow Approved` 前仍不得连接真实首页接口。
