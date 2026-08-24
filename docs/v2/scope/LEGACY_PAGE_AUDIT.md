# KingClub 1.1.37 页面与路由审计

- 状态：`Reviewed for Scope Input`
- 来源：`C:\Users\Poplar\Desktop\KingClub-app`
- 基线：`master / 505d222 / 1.1.37`

## 1. 审计方法与限制

本次检查了 `app.json`、69 个页面目录、WXML 可见文案、页面 JS、静态导航目标、超级接口编号和 `index` 内部 tab。审计结论是产品范围输入，不代表旧接口、安全模型或页面结构可直接复用。

限制：`index`、设置和管理面板的部分菜单来自超级接口动态 JSON。页面虽然没有静态调用方，也可能由服务端菜单进入，因此统一标记其角色和建议去向，而不是仅按静态引用删除。

## 2. 旧版逻辑导航

旧版实际导航大致为：

```text
登录/注册
  -> 首页大容器
       |- 首页：一起玩、VIP 组局、扫码
       |- 通讯录/会话
       |- 短视频推荐
       |- 私人储物柜
       `- 我的：资料、资产、设置、管理入口
```

底部 tab 由服务端返回；普通用户和有社交能力的用户可能获得不同数量的 tab。V2 必须显式冻结 tab 和角色权限，不能继续由服务端任意下发路由字符串。

## 3. 69 个物理路由逐项审计

范围标签：

- `R1`：建议进入本期普通会员首发，但允许在 V2 中拆分或合并。
- `D`：待用户决定的可选功能包。
- `Later`：已识别但建议后续单独立项。
- `Exclude`：不进入消费者 Flutter 首发。

| # | 旧路由 | 旧版用户任务 | 角色 | 建议 | V2 去向 |
|---:|---|---|---|---|---|
| 1 | `pages/login/login` | 品牌登录入口、协议勾选 | 会员 | R1 | 拆为启动鉴权、手机号登录、协议确认 |
| 2 | `pages/openVideo/openVideo` | 查看用户视频/短视频 | 会员 | R1 | 合并为短视频流/媒体预览 |
| 3 | `pages/shoping/shoping` | 扫码点单、选商品、购物袋 | 会员 | R1 | 扫码点单商品与购物车页 |
| 4 | `pages/shoping2/shoping2` | 点单结算、券/金币/余额抵扣 | 会员 | R1 | 点单确认页 |
| 5 | `pages/shoping3/shoping3` | 查看已购点单明细 | 会员 | R1 | 统一订单详情页 |
| 6 | `pages/index/index` | 首页、聊天/通讯录、视频、储物柜、我的 | 会员 | R1 + D | 拆成 App Shell 与各领域独立页面；储物柜属于可选包 |
| 7 | `pages/regist/regist` | 手机验证码登录/注册 | 会员 | R1 | 手机号页 + 验证码页 |
| 8 | `pages/regist2/regist2` | 实名、身份证、年龄和人脸核验 | 会员 | R1 | 实名与成年核验页 |
| 9 | `pages/regist3/regist3` | 上传两张会员审核照片 | 会员 | R1 | 会员形象审核资料页 |
| 10 | `pages/regist4/regist4` | 选择着装与音乐偏好 | 会员 | R1 | 偏好设置第一步 |
| 11 | `pages/regist5/regist5` | 选择酒类与活动偏好、提交审核 | 会员 | R1 | 偏好设置第二步 |
| 12 | `pages/success/success` | 用参数拼接各种成功/失败结果 | 多角色 | Exclude | 状态归属各业务页；禁止通用 URL 文案结果页 |
| 13 | `pages/savecode/savecode` | 展示存酒/物品取件码 | 会员 | D | 可选“私人储物柜”包 |
| 14 | `pages/friendinfo/friendinfo` | 查看陌生人/朋友资料并发起联系 | 会员 | R1 | 统一用户主页的关系状态 |
| 15 | `pages/friendinfo2/friendinfo2` | 修改朋友备注、电话和描述 | 会员 | R1 | 好友备注页 |
| 16 | `pages/friendinfo3/friendinfo3` | 设置关系权限、拉黑、删除 | 会员 | R1 | 关系权限页 |
| 17 | `pages/newfriend/newfriend` | 查看新的朋友申请 | 会员 | R1 | 好友申请列表页 |
| 18 | `pages/newfriendInfo/newfriendInfo` | 查看并处理好友申请 | 会员 | R1 | 合并进统一用户主页/申请详情状态 |
| 19 | `pages/createfriendinfo/createfriendinfo` | 编辑并发送好友申请 | 会员 | R1 | 添加好友申请页 |
| 20 | `pages/chat/chat` | 单聊/群聊、媒体、引用、转发、红包等 | 会员 | R1 + D | 首发保留稳定单聊；群聊和红包按可选包拆分 |
| 21 | `pages/aggreement/index` | 阅读用户协议/隐私政策 | 访客/会员 | R1 | 统一法律文档阅读页 |
| 22 | `pages/Choose/Choose` | 一起玩 AA 预订列表和状态 | 会员 | R1 | AA 预订页 |
| 23 | `pages/Choose2/Choose2` | VIP 组局、邀请、踢人、付款 | 会员/局长 | R1 | 拆为组局列表/详情和局长管理 |
| 24 | `pages/ticket/ticket` | 查看入场二维码 | 会员 | R1 | 入场凭证页 |
| 25 | `pages/order/order` | 查看 AA 卡座/套餐并抢订 | 会员 | R1 | AA 卡座套餐详情页 |
| 26 | `pages/order2/order2` | 确认 AA 订单并抵扣/支付 | 会员 | R1 | AA 确认订单页 |
| 27 | `pages/addfriend/addfriend` | 扫码添加会员 | 会员 | R1 | 添加好友/扫码页 |
| 28 | `pages/mycode/mycode` | 展示个人或群二维码 | 会员 | R1 + D | 个人二维码首发；群二维码随群聊包 |
| 29 | `pages/myinfo/myinfo` | 编辑头像和个人字段、支付密码入口 | 会员 | R1 | 编辑个人资料页 |
| 30 | `pages/mybalance/mybalance` | 查看余额、金币、钻石与流水 | 会员 | R1 | 钱包与资产流水页 |
| 31 | `pages/about/about` | 关于、版本、协议和备案信息 | 会员 | R1 | 关于页 |
| 32 | `pages/getWine/getWine` | 员工扫码确认交付存酒 | 员工 | Exclude | 以后建设员工端或 Web 管理端 |
| 33 | `pages/modiffypwd/modiffypwd` | 修改支付密码 | 会员 | R1 | 支付安全页 |
| 34 | `pages/blacklist/blacklist` | 查看黑名单 | 会员 | R1 | 黑名单页 |
| 35 | `pages/send-redpacket/send-redpacket` | 聊天发红包并支付 | 会员 | D | 可选“红包与转赠”包 |
| 36 | `pages/pay/pay` | 多业务支付编排和结果展示 | 会员 | R1 | 支付处理/结果页；金额由服务端确定 |
| 37 | `pages/manage/manage` | 管理员面板与分佣入口 | 管理员/代理 | Exclude | 独立运营端 |
| 38 | `pages/managecode/managecode` | 管理员推广二维码和赠券 | 管理员/代理 | Exclude | 独立运营端 |
| 39 | `pages/sysmessage/sysmessage` | 系统、订单、签到等通知 | 会员 | R1 | 系统通知页 |
| 40 | `pages/detail-pages/detail-pages` | 顾客详情、资产、人工充值 | 管理员/财务 | Exclude | 独立运营端，禁止放消费者 App |
| 41 | `pages/manageclient/manageclient` | 特约顾客和活跃榜 | 代理/运营 | Exclude | 独立运营端 |
| 42 | `pages/allclient/allclient` | 全部会员、申请、黑名单 | 管理员 | Exclude | 独立运营端 |
| 43 | `pages/detail-order/detail-order` | 管理端订单详情 | 管理员 | Exclude | 独立运营端；消费者另建订单详情 |
| 44 | `pages/agencybalance/agencybalance` | 代理提成流水 | 代理 | Exclude | 独立代理/运营端 |
| 45 | `pages/addagency/addagency` | 配置管理员/代理和提成比例 | 超级管理员 | Exclude | 独立运营端 |
| 46 | `pages/withdrawal/withdrawal` | 代理佣金提现和银行卡 | 代理 | Exclude | 独立代理端；不是消费者钱包提现 |
| 47 | `pages/send-goldCoin/send-goldCoin` | 聊天内转赠金币 | 会员 | D | 可选“红包与转赠”包 |
| 48 | `pages/seat-manage/seat-manage` | 管理座位与订单 | 员工/运营 | Exclude | 独立员工端 |
| 49 | `pages/cash-register/cash-register` | 摇动手机计分实验页 | 未明确 | Exclude | 无静态入口且绑定缺失，不迁移 |
| 50 | `pages/vip-order/vip-order` | 创建 VIP 组局、选套餐并付款 | 会员/局长 | R1 | 组局创建页 |
| 51 | `pages/order-manage/order-manage` | 局长查看组局、邀请/踢人、追加点单 | 局长 | R1 | 组局管理页 |
| 52 | `pages/select-chat/select-chat` | 选择聊天好友发送组局邀请 | 会员 | R1 | 通用联系人选择页 |
| 53 | `pages/setup/setup` | 系统/软件/收支配置 | 超级管理员 | Exclude | 独立运营端 |
| 54 | `pages/edit_info/edit_info` | 编辑运营推广内容 | 运营 | Exclude | 独立 CMS |
| 55 | `pages/downloadAPK/downloadAPK` | 小程序内下载旧 Android APK | 旧平台 | Exclude | 由应用商店/发布渠道替代 |
| 56 | `pages/setting/setting` | 设置、动态菜单、退出登录 | 会员 | R1 | 设置页；服务端不下发任意路由 |
| 57 | `pages/bind_account/bind_account` | 动态账号/代理绑定 | 未明确 | Later | 先确认统一身份绑定还是代理关系绑定 |
| 58 | `pages/del_user_account/del_user_account` | 永久注销账号 | 会员 | R1 | 账号注销页 |
| 59 | `pages/text_editor/text_editor` | 编辑运营软文/广告 | 运营 | Exclude | 独立 CMS |
| 60 | `pages/chat_more/chat_more` | 聊天详情、成员、群设置、历史 | 会员 | R1 + D | 单聊详情首发；群管理随可选包 |
| 61 | `pages/chat_more_select/chat_more_select` | 转发或增删群成员 | 会员 | D | 可选完整群聊包 |
| 62 | `pages/group_modify_name/group_modify_name` | 群名、群备注、群昵称 | 群成员/管理员 | D | 可选完整群聊包 |
| 63 | `pages/group_notice/group_notice` | 编辑群公告 | 群管理员 | D | 可选完整群聊包 |
| 64 | `pages/group_manage_setup/group_manage_setup` | 群审批、管理员、转让、解散 | 群主/管理员 | D | 可选完整群聊包 |
| 65 | `pages/group_bg_setup/group_bg_setup` | 设置聊天背景 | 会员 | D | 可选完整群聊包 |
| 66 | `pages/chat_history/chat_history` | 搜索聊天历史和媒体 | 会员 | D | 可选完整群聊包，也可独立降级加入 |
| 67 | `pages/userInfo/userInfo` | 用户主页、关注、分组和关系设置 | 会员 | R1 | 统一用户主页 |
| 68 | `pages/logs/logs` | 模板日志页 | 调试 | Exclude | 不进入产品 |
| 69 | `releaseSystem/pages/createWorks/createWorks` | 拍摄/选择媒体并发布作品 | 会员 | D | 可选“作品发布”包 |

## 4. 汇总

| 分类 | 旧物理路由数 | 说明 |
|---|---:|---|
| R1（含局部拆分） | 41 | 普通会员首发建议输入 |
| D | 10 | 群聊、发布、红包/转赠、私人储物柜 |
| Later | 1 | 动态账号绑定，语义未确认 |
| Exclude | 17 | 员工/代理/运营、调试、APK 和通用结果页 |
| 合计 | 69 | 与 `app.json` 一致 |

这里统计旧物理路由，不等于 V2 页面数。V2 会拆分超大页、合并重复状态，并新增旧版缺失但核心闭环必需的订单中心和 App Shell。

