# VIP 组局

- Scope ID：`KC-F-024`
- 文档状态：`Approved for Development`
- 所属业务域：`club`
- M0 范围：`In Release Scope`
- 设计版本：`VIP Party v1`
- 最后更新：2026-08-25

## 目标与用户价值

让合格会员浏览公开或受邀的 VIP 组局，理解费用和规则后加入；也可创建并管理自己的组局、邀请好友和查看参与状态。

## 已确认事实

- 旧版由 `Choose2` 同页承载日期、组局卡片、成员、邀请、票据和踢人；`vip-order` 同页完成配置、计价与支付；`order-manage` 混入消费者、员工和管理员能力。
- 旧版通过 `orderType/isHost/orderStatus/isSex` 等数字或布尔值表达互相冲突的语义。
- 旧客户端计算套餐、优惠券、余额、金币和现金金额，并把账号和订单 JSON 传给支付页。
- 旧版允许按颜值/年龄/性别设置参与限制，并允许局长踢人后由客户端组合固定 100 元赔付。
- 完整群聊、员工点单确认、服务员指派和管理端订单状态不在消费者 App 本期范围。

## 当前建议

- 角色固定为 `viewer | participant | host`；创建者即 host，不提供“创建但不做局长”。
- 费用策略使用明确枚举 `splitPerMember | hostSponsored`，可见性使用 `public | inviteOnly`，不再用反向布尔值。
- 去掉颜值分、性别比例和自定义年龄筛选；所有用户仍需满足会员审核、成年和账号可用资格。
- 公开列表只展示局长公开资料摘要、时间、套餐、模糊余量和人均/主办费用摘要；成员名单仅对已确认成员和局长开放。
- 加入在 KC-P-030 内完成规则确认并创建加入意图；需要付款时交给 KC-P-038，不新建隐藏支付页面。
- 创建页只提交服务端配置草稿和权威报价；支付/免付确认后才正式建局。
- 局长可邀请好友、撤销未接受邀请、关闭/开启招募；不能自行移除已付款成员、修改已锁定价格/套餐或操作员工账单。
- 已付款成员异常移除、退款和赔付交由后续订单/客服流程，服务端计算全部金额，消费者端不硬编码 100 元。
- 不因组局自动创建群聊；邀请复用批准的单聊业务卡片和联系人单选流程。

## 页面与文档

- [KC-P-030 VIP 组局列表/详情页](pages/page_vip_party_detail/README.md) — `Approved for Development`
- [KC-P-031 VIP 组局创建页](pages/page_vip_party_create/README.md) — `Approved for Development`
- [KC-P-032 局长组局管理页](pages/page_vip_party_management/README.md) — `UI Mock Implemented / Android Device Verified`
- [旧版审计](legacy_audit.md)
- [流程与导航](flow_and_navigation.md)
- [状态机](state_machine.md)
- [数据与 Fake 契约](data_and_api.md)
- [权限、隐私与安全](permissions_privacy_security.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 颜值/性别筛选、未成年人、群聊、多人群发邀请、候补队列、转让局长。
- 局长自助踢已付款成员、客户端赔付计价、退款自助、服务员指派和员工确认账单。
- 真实组局、支付、推送、WebSocket 或外部分享 SDK 接入。

## 已确认决策

1. 创建者固定为局长；费用只分“成员各付”和“局长请客”，可见性只分“公开”和“仅邀请”。
2. 去掉颜值分、性别比例和自定义年龄筛选，仅保留成年人会员资格。
3. 局长只能撤销未接受邀请或移除未付款占位；已付款成员不能在 App 内直接踢出。
4. 组局不自动创建群聊；邀请只通过单人联系人选择发送受控业务卡片。
5. 套餐、费用策略和容量在建局确认后不可由消费者修改；取消、退款、赔付在订单模块统一设计。

## 开发门禁

本功能已达到文档准入；全部 48 页批准前不创建 Flutter UI，全局 `UI Flow Approved` 前不接真实组局、订单、支付、推送或消息服务。
