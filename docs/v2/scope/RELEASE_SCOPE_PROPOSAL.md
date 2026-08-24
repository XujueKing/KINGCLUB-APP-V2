# Flutter V2 本期功能与页面范围提案

- 状态：`In Review`
- 当前提案：普通会员首发 46 个逻辑页面
- 确认方式：先确认首发主体，再逐个确认 4 个可选包

## 1. 范围原则

- **当前建议**：Flutter 首发是普通会员 App，不把员工、财务、代理和超级管理员后台混入同一个客户端。
- **当前建议**：保留 KingClub 的消费差异化能力：会员审核、一起玩 AA、VIP 组局、扫码点单、支付和入场。
- **当前建议**：首发保留好友、会话和稳定单聊；复杂群管理作为独立决策包。
- **当前建议**：短视频浏览进入首发，作品发布单独决策。
- **已确认事实**：所有纳入页面先逐页完成文档，再统一做 UI Mock；整 App UI 验收前不接真实服务。

## 2. 本期功能清单

| 功能 ID | 业务域 | 功能 | 优先级 | 首发建议 |
|---|---|---|---|---|
| KC-FND-01 | foundation | 应用启动、环境和失败兜底 | P0 | 纳入 |
| KC-FND-02 | foundation | App Shell、底部导航和返回规则 | P0 | 纳入 |
| KC-FND-03 | foundation | 设计系统、主题和基础组件 | P0 | 纳入 |
| KC-FND-04 | foundation | Mock 场景与 Fake Repository | P0 | 纳入 |
| KC-FND-05 | foundation | 网络/超级接口端口与错误模型 | P0 | 仅文档和 Fake |
| KC-FND-06 | foundation | 会话、安全存储和单设备状态端口 | P0 | 仅文档和 Fake |
| KC-FND-07 | foundation | 日志、埋点、隐私和崩溃端口 | P0 | 仅文档和 Fake |
| KC-FND-08 | foundation | 相机、相册、扫码、定位和通知权限 | P0 | 先定义 Fake/权限状态 |
| KC-ID-01 | identity | 手机号验证码登录/注册 | P0 | 纳入 |
| KC-ID-02 | identity | 协议目录、阅读与同意 | P0 | 纳入 |
| KC-ID-03 | identity | 实名、成年和人脸核验 | P0 | 纳入 |
| KC-ID-04 | identity | 会员形象资料提交与审核状态 | P0 | 纳入 |
| KC-ID-05 | identity | 兴趣偏好初始化 | P1 | 纳入 |
| KC-HOME-01 | home | 首页聚合和核心入口 | P0 | 纳入 |
| KC-HOME-02 | home | 安全扫码分流 | P0 | 纳入 |
| KC-SOC-01 | social | 通讯录、好友申请与添加好友 | P0 | 纳入 |
| KC-SOC-02 | social | 用户主页、关注和关系状态 | P0 | 纳入 |
| KC-SOC-03 | social | 好友备注、权限、黑名单 | P1 | 纳入 |
| KC-MSG-01 | messaging | 会话列表和系统通知 | P0 | 纳入 |
| KC-MSG-02 | messaging | 稳定单聊、文本/图片/视频/引用/转发 | P0 | 纳入 |
| KC-MSG-03 | messaging | 单聊详情、免打扰和本地清理 | P1 | 纳入 |
| KC-CONT-01 | content | 短视频/作品浏览 | P1 | 纳入 |
| KC-CLUB-01 | club | 一起玩 AA 查询、选座和确认 | P0 | 纳入 |
| KC-CLUB-02 | club | VIP 组局创建、详情、邀请和局长管理 | P0 | 纳入 |
| KC-CLUB-03 | club | 入场凭证 | P0 | 纳入 |
| KC-COM-01 | commerce | 扫码点单、商品和购物车 | P0 | 纳入 |
| KC-COM-02 | commerce | 服务端计价的订单确认 | P0 | 纳入 |
| KC-COM-03 | commerce | 订单中心、订单详情和支付结果 | P0 | 纳入；订单中心为 V2 新补 |
| KC-WAL-01 | membership_wallet | 余额、金币、钻石和流水只读 | P1 | 纳入 |
| KC-PRO-01 | profile_settings | 我的主页和编辑资料 | P0 | 纳入 |
| KC-PRO-02 | profile_settings | 个人二维码 | P1 | 纳入 |
| KC-PRO-03 | profile_settings | 设置、退出和账号注销 | P0 | 纳入 |
| KC-PRO-04 | profile_settings | 支付安全 | P1 | 纳入 |
| KC-PRO-05 | profile_settings | 关于与法律文档 | P1 | 纳入 |

## 3. 本期 46 个逻辑页面

`docStatus` 只描述文档状态；除现有四个登录页外，下表均需创建独立目录后才能评审。

### 3.1 Foundation 与身份（10）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-001 | 启动鉴权页 | 已有 `page_auth_bootstrap` | Approved for Development |
| KC-P-002 | 手机号登录页 | 已有 `page_mobile_login` | Approved for Development |
| KC-P-003 | 验证码页 | 已有 `page_sms_verification` | Approved for Development |
| KC-P-004 | 协议确认页 | 已有 `page_terms_consent` | Approved for Development |
| KC-P-005 | 实名与成年核验页 | 旧 `regist2` | Not Started |
| KC-P-006 | 会员形象资料页 | 旧 `regist3` | Not Started |
| KC-P-007 | 着装与音乐偏好页 | 旧 `regist4` | Not Started |
| KC-P-008 | 酒类与活动偏好页 | 旧 `regist5` | Not Started |
| KC-P-009 | 会员审核状态页 | 替代参数化 `success` | Not Started |
| KC-P-010 | App Shell/底部导航容器 | 拆自旧 `index` | Not Started |

### 3.2 首页与内容浏览（3）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-011 | 首页 | 拆自旧 `index` 首页 | Not Started |
| KC-P-012 | 扫码识别与安全分流页 | 好友码、桌码、入场码 allowlist | Not Started |
| KC-P-013 | 短视频/作品流页 | 旧 `index` 视频 tab + `openVideo` | Not Started |

### 3.3 社交关系（8）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-014 | 通讯录页 | 拆自旧 `index` | Not Started |
| KC-P-015 | 添加好友/扫码页 | 旧 `addfriend` | Not Started |
| KC-P-016 | 好友申请列表页 | 旧 `newfriend` | Not Started |
| KC-P-017 | 用户主页 | 合并 `friendinfo`、`newfriendInfo`、`userInfo` 的状态 | Not Started |
| KC-P-018 | 发送好友申请页 | 旧 `createfriendinfo` | Not Started |
| KC-P-019 | 好友备注页 | 旧 `friendinfo2` | Not Started |
| KC-P-020 | 关系权限页 | 旧 `friendinfo3` | Not Started |
| KC-P-021 | 黑名单页 | 旧 `blacklist` | Not Started |

### 3.4 消息（5）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-022 | 会话列表页 | 拆自旧 `index` | Not Started |
| KC-P-023 | 系统通知页 | 旧 `sysmessage` | Not Started |
| KC-P-024 | 单聊页 | 从旧 `chat` 收敛首发消息类型 | Not Started |
| KC-P-025 | 单聊详情页 | 从旧 `chat_more` 收敛 | Not Started |
| KC-P-026 | 联系人选择页 | 转发消息、发送组局邀请 | Not Started |

### 3.5 到店、组局与入场（7）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-027 | 一起玩 AA 预订页 | 旧 `Choose` | Not Started |
| KC-P-028 | AA 卡座套餐详情页 | 旧 `order` | Not Started |
| KC-P-029 | AA 确认订单页 | 旧 `order2` | Not Started |
| KC-P-030 | VIP 组局列表/详情页 | 旧 `Choose2` | Not Started |
| KC-P-031 | VIP 组局创建页 | 旧 `vip-order` | Not Started |
| KC-P-032 | 局长组局管理页 | 旧 `order-manage` | Not Started |
| KC-P-033 | 入场凭证页 | 旧 `ticket` | Not Started |

### 3.6 点单、订单与支付（5）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-034 | 扫码点单商品/购物车页 | 旧 `shoping` | Not Started |
| KC-P-035 | 点单确认页 | 旧 `shoping2` | Not Started |
| KC-P-036 | 订单中心页 | V2 新补：统一查看 AA、组局和点单订单 | Not Started |
| KC-P-037 | 订单详情页 | 合并消费者 `shoping3` 等状态，不复用管理详情 | Not Started |
| KC-P-038 | 支付处理与结果页 | 重构旧 `pay`，禁止客户端确认金额/成功 | Not Started |

### 3.7 钱包、个人与设置（8）

| Scope ID | 页面 | 来源/说明 | docStatus |
|---|---|---|---|
| KC-P-039 | 钱包与资产流水页 | 旧 `mybalance` | Not Started |
| KC-P-040 | 我的主页 | 拆自旧 `index` 我的 tab | Not Started |
| KC-P-041 | 编辑个人资料页 | 旧 `myinfo` | Not Started |
| KC-P-042 | 个人二维码页 | 旧 `mycode` 个人模式 | Not Started |
| KC-P-043 | 设置页 | 旧 `setting`，改为客户端固定 allowlist | Not Started |
| KC-P-044 | 支付安全页 | 旧 `modiffypwd` | Not Started |
| KC-P-045 | 账号注销页 | 旧 `del_user_account` | Not Started |
| KC-P-046 | 关于与法律文档页 | 合并 `about` 与只读协议查看 | Not Started |

## 4. 四个待用户确认的可选包（共 11 页）

| 决策包 | 建议 | 新增页面 | 影响 |
|---|---|---:|---|
| D1 完整群聊与群管理 | 暂缓 | 6 | 群资料编辑、群公告、群管理、成员选择、聊天背景、历史搜索；显著增加权限和消息状态复杂度 |
| D2 作品发布 | 暂缓 | 1 | 拍摄/相册、编辑、位置、可见性、上传恢复和内容审核 |
| D3 红包与金币转赠 | 暂缓 | 2 | 红包创建、金币转赠；涉及资产、支付、风控和聊天消息一致性 |
| D4 私人储物柜 | 建议纳入（KingClub 差异化） | 2 | 储物柜、存酒/物品取件码；员工扫码交付仍不进入会员 App |

说明：若 D4 纳入，本期变为 48 页；若 D1～D4 全部纳入，本期变为 57 页。聊天历史搜索包含在 D1 中，不另行重复计数。

## 5. 明确不进入消费者 Flutter 首发

### 5.1 角色后台

- 员工存酒交付、座位管理。
- 管理员/代理面板、管理码、顾客列表/详情。
- 人工充值、管理端订单详情、提成流水、代理设置、佣金提现。
- 系统配置、运营推广内容和富文本 CMS。

这些能力以后应评审为独立员工/运营 App 或 Web 管理端，不应通过隐藏菜单塞入普通会员 App。

### 5.2 旧平台或技术页面

- 参数化通用成功/失败页：改为各功能自己的状态。
- APK 下载页：由 App Store、Android 应用市场或正式分发渠道替代。
- `logs` 调试页和摇一摇计分实验页。
- 服务端动态下发任意客户端路由。

### 5.3 后续单独确认

- `bind_account` 的真实业务语义：如果是代理绑定，归运营域；如果是跨 App 身份绑定，必须重新做统一身份与安全设计。
- 旧聊天记录、订单、余额、金币、实名资料各自迁移的历史范围。
- 退款/售后虽然旧版没有完整独立页面，但若首发支持真实支付，必须在接入前决定由 App、客服还是线下流程承接。

## 6. 用户确认项

要冻结 M0 范围，需要用户明确确认：

1. 是否接受“46 页普通会员首发主体”。
2. D1 完整群聊与群管理是否纳入本期。
3. D2 作品发布是否纳入本期。
4. D3 红包与金币转赠是否纳入本期。
5. D4 私人储物柜是否纳入本期（当前建议纳入）。
6. 是否确认员工/代理/财务/运营页面全部移出消费者 App。

确认后才为最终纳入项批量建立 `docs/features/<domain>/<feature>/pages/<page>/` 目录；建立目录不代表文档已批准。
