# 钱包与资产流水

- Scope ID：`KC-F-030`
- 文档状态：`Approved for Development`
- 所属业务域：`membership_wallet`
- M0 范围：`In Release Scope`
- 设计版本：`Read-only Asset Ledger v1`
- 最后更新：2026-08-25

## 目标与用户价值

让会员只读查看 KingClub 独立业务域内受支持的余额、金币、钻石及其权威流水，能够区分可用、冻结、处理中和已冲正状态。

## 已确认事实

- 旧 `mybalance` 把“订单、余额、金币、钻石”作为同级账单 tab；2026-08-28 用户要求 UI 完全复刻，因此四个 tab 保留。订单数据仍由 KC-P-036/037 的 OrderRef/read model 提供，不并入钱包资产模型。
- 旧页面把本地 `preUserInfo.userAccount` 作为查询身份，并解析超级接口返回的 JSON 字符串。
- 旧分页使用页码并在客户端合并排序，存在重复、顺序错误和旧页覆盖风险。
- 旧支付页面在客户端计算余额/金币抵扣；该做法已被支付契约禁止。
- D3 红包/金币转赠与代理佣金提现已明确暂缓；各 App 钱包、金币和订单严格独立。

## 当前建议

- 资产摘要与流水只从当前 KingClub 会话查询，路由和请求不接受 userAccount。
- 余额使用最小货币单位整数；金币和钻石使用整数单位，三者不换算、不相加为“总资产”。
- 服务端通过 `supportedAssets` 决定展示余额、金币、钻石；未启用的资产隐藏，不用假 `0` 占位。
- 每种资产分别展示 available、frozen、pending（如适用）及 `asOf`；客户端不通过流水求余额。
- 流水使用稳定 cursor，状态统一为 `pending/posted/reversed`；冲正记录不可静默删除。
- 首发完全只读，不显示充值、提现、转赠、红包、兑换或支付分摊输入。
- 关联订单可通过服务端提供的 `OrderRef` 进入 KC-P-037；普通资产流水不创建额外详情页。

## 页面与文档

- [KC-P-039 钱包与资产流水页](pages/page_asset_ledger/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [资产与流水语义](asset_ledger_model.md)
- [隐私与一致性](privacy_and_consistency.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- D3 红包/金币转赠、充值、提现、兑换、礼物、银行卡、代理佣金和跨 App 共享资产。
- 资产流水独立详情页、真实超级接口、支付/银行 SDK 或实时资产推送。

## 已确认产品决策

1. 首发支持余额、金币、钻石三类独立资产，但只展示服务端明确启用的类型。
2. 不把三类资产换算或相加为总资产。
3. 账单页视觉保留旧版“订单”tab；订单详情和业务归属仍在订单中心，钱包不自行重建订单。
4. 本期钱包完全只读，不提供充值、提现、兑换、红包或转赠。
5. 流水关联订单时可进入订单详情；其他流水在当前页展开摘要，不新增页面。

## 开发门禁

用户已于 2026-08-25 批准本版本；全部 48 页批准前不创建 Flutter UI，全局 `UI Flow Approved` 前不接真实资产、订单、支付或推送能力。
