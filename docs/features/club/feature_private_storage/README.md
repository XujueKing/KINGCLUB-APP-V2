# 私人储物柜

- Scope ID：`KC-F-026`
- 文档状态：`In Review`
- 所属业务域：`club`
- M0 范围：`In Release Scope`
- 设计版本：`Private Storage v1`
- 最后更新：2026-08-25

## 目标

查看本人存酒和物品的权威数量、剩余量、有效期及可取状态，并向工作人员出示短时、可撤销、防重放的取件凭证。

## 已确认事实

- 旧首页把存酒与券/物品嵌入大 swiper，并解析 JSON 字符串。
- 旧 `savecode` 从 URL 反序列化完整对象，用 storedId、userAccount 拼静态网页二维码，并明文显示永久 storedId。
- 旧页面每 2 秒轮询状态，以数量减少或 storedStatus 判断成功；并直接展示库房位置和保存人员。
- 员工取酒属于角色后台，已明确移出消费者 App。

## 当前建议

- 列表只查询当前会话本人，按 `wine/item` 分类，路由不携带账号或储物对象。
- 详情展示公开品名、数量/剩余量、存入和到期时间、权威状态；不展示内部库位、员工姓名或永久编号。
- 取件页只接收 `StorageItemRef`，服务端签发 30 秒轮换的 `PickupDisplayToken`；码不含 URL、账号或 storedId。
- 只有授权员工核验端能完成交付；消费者扫码/页面不能自行核销。
- 交付事件只触发权威重读；结果未知时不显示“已取出”，不密集轮询。
- 离线不生成或延长二维码，改为工作人员安全核验。

## 文档

- [KC-P-047 私人储物柜页](pages/page_private_storage/README.md) — `In Review`
- [KC-P-048 存酒/物品取件码页](pages/page_storage_pickup_code/README.md) — `In Review`
- [旧版审计](legacy_audit.md)
- [安全与 Fake 契约](security_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

员工扫码交付 UI、库房管理、代领/转赠、续期、争议处理、真实接口/扫码/推送能力。

## 待用户确认

1. 存酒和物品统一在储物柜中分类展示。
2. 不显示内部库位、员工姓名和永久 storedId。
3. 取件码采用默认 30 秒轮换的动态不透明二维码。
4. 只有授权员工可核销，消费者不能自行宣布取件成功。
5. 离线不提供永久备用码，由工作人员人工核验。

## 门禁

用户批准后才准入；全局 `UI Flow Approved` 前不接真实储物、凭证或员工核销能力。
