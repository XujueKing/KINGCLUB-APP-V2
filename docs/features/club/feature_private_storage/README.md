# 私人储物柜

## 2026-10-09 原商品酒瓶图片修正

177 投影修正：素材的透明画布不能当成实际瓶身。服务端从生成轮廓时的有效像素记录归一化 bodyBounds，页面以该矩形的实际宽高、中心和底边计算椭圆；大图、九宫格及翻转面统一。原瓶图和图层画布不裁切，图片比例保持；缺少边界的旧素材兼容全画布。覆盖有大幅透明留白、缩略比例和非法可选边界的检查。

177 已完成签名构建、安装并读取 iPhone 应用列表确认 1.2.0 (177)。13 项相关测试与改动文件分析通过。首次安装后截图读取到锁屏，已请用户保持储物袋芝华士页面亮屏；实机投影视觉验收尚待截图，不把安装成功作为视觉验收。

收银台寄存的新品种此前只有通用 `assetKey=wine`，会员端无法显示其商品图片。既有储物列表、详情和取码回参现在携带同门店来源商品的 `bottleMaterial`。大图、九宫格、过期列表及翻转面共用原 PNG/缩略图/轮廓；不改寄存数量、余量、有效期及提取权限。

素材限服务端签发的同源附件地址，校验来源门店、版本、摘要与六个图层；使用会员隔离的持久缓存和稳定内容标识，签名续期不重复缓存。无素材的旧记录保留原内置图；未知酒瓶翻转时不再套用伏特加轮廓。页面仍请求 K260912000401，一次回齐图片资料，服务端使用 `kingclub_storage_read`（425）；静态图层按需下载不属于额外业务接口。

实机第175版已看见昨日寄存香槟的大图及九宫格缩略图。投影修正直接复用此前全部酒瓶预览已使用的 `BottleVisualBacking`：椭圆宽度为瓶宽217.2/146、高度为瓶高40.08/453、中心靠近瓶底；正反面及缩略图统一比例，不再另画圆角长条。既有预览、小屏、翻转与素材校验16项检查及改动文件分析通过。第176版已安装，设备读取核对1.2.0/176，保留原数据；椭圆视觉及AA渐变实机截图待解锁后确认。

服务端酒瓶素材上传统一压缩：透明PNG大图长边不超过1600、独立缩略图不超过384×768，小图不放大，已有索引色PNG保持索引色以免缩略图体积反增。摘要以规范化主图为准，资料引用更新后自动刷新内容缓存，不需按酒名添加客户端分支。已有素材通过运维只读清单和事务替换流程批量优化；尚无来源图的商品资料不以占位图冒充已完成素材。

## 2026-09-12 增量授权与实现

用户已明确要求真实接口与数据库，以下M0仅Mock范围为历史记录，储物柜本次按真实接入推进。最新实现、验证和限制见 [实施记录](2026-09-12-implementation.md) 与 [数据审查](database_review.md)。旧余额迁移和员工管理界面尚未完成。


- Scope ID：`KC-F-026`
- 文档状态：`Approved for Development`
- 所属业务域：`club`
- M0 范围：`In Release Scope`
- 设计版本：`Private Storage v1 / Legacy Private Storage Replica v1`
- 批准日期：2026-08-26

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

- [KC-P-047 私人储物柜页](pages/page_private_storage/README.md) — `Approved for Development`
- [KC-P-048 存酒/物品取件码页](pages/page_storage_pickup_code/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [安全与 Fake 契约](security_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

员工扫码交付 UI、库房管理、代领/转赠、续期、争议处理、真实接口/扫码/推送能力。

## 已确认决策

1. 存酒和物品统一在储物柜中分类展示。
2. 不显示内部库位、员工姓名和永久 storedId。
3. 取件码采用默认 30 秒轮换的动态不透明二维码。
4. 只有授权员工可核销，消费者不能自行宣布取件成功。
5. 离线不提供永久备用码，由工作人员人工核验。

用户于 2026-08-26确认以上方案。

## 门禁

本功能与两页均已达到文档准入；全局 `UI Flow Approved` 前不接真实储物、凭证或员工核销能力。


2026-09-14 储物袋修正：券面正反面按实际文字高度计算内容，超过已有展示框时等比缩小，避免文字溢出；不移动标题、分类或九宫格。页面挂载即预取，不等切入栏目才请求；初次读取不显示转圈，刷新保留已展示物品。真实请求仍异步，不能承诺冷启动零耗时。

验证与装机：储物分类/双轴分页/小屏大字体券面正反面/无转圈预取 5 项及取件流程 8 项通过；页面与测试 analyze 无问题。旧流程测试标题由已弃用的“私人储物柜”更新为用户已确认的“储物袋”。Profile ARM64 构建 221.7 秒成功、覆盖安装 Success；用户体验包默认脚本改用 Profile ARM64，Debug 仅专项调试。手机流畅度仍需实测，不以模式切换保证所有卡顿消失。


## 2026-10-05 storage notification correction

Storage events now reuse the animated foreground chat banner (KING icon, slide/fade, swipe dismissal) and show the authenticated notification body. A missing body uses neutral storage-updated text; deposits no longer use the hard-coded redemption message.

The storage tab has its own red dot, independent of message read receipts. The APP compares the authorized storage list with the last successfully viewed snapshot saved per member in secure local storage. Opening storage refreshes the list and acknowledges the displayed snapshot only after successful loading. New deposits and changed remaining quantities restore the dot; reconnect/app resume reconcile missed realtime events. Switching accounts discards in-flight state. No extra backend table or interface.

Validation: 19 storage attention, storage feedback and shell tests passed; changed Dart sources analyze cleanly. One existing expired-storage test expected the obsolete page title; its assertion now checks return to the storage page. iPhone installation status is reported separately from these code checks.

Release evidence: iOS workflow 37249157391 succeeded for d05d3353. Encrypted artifact integrity and development signing/profile were checked; the connected iPhone was upgraded without uninstalling. Installed bundle com.lingmei.kingclub reports build 115. Physical red-dot/banner observation remains separate from installation and automated tests.
