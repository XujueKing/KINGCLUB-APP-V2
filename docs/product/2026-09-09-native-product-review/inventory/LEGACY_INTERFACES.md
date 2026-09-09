# KING CLUB 接口分类与依赖清单

- 已确认事实：`s_interface.interfaceType -> s_interface_type.typeId`；通过 `parentId` 追溯“酒吧”分类树。
- 根：`S232202502210097 酒吧`；子类：`S232202502210099 App`（92）、`S232202502210100 服务器端使用`（11）。快照共 103，另列 3 个群管理增量接口。
- 当前客户端 82 个静态编号中 79 个命中快照；分类目录还补出 24 个没有静态编号引用的接口。
- “服务器端使用”是分类而非可靠权限保证：头像修改编号 `S231202504160682` 仍出现在客户端。
- 依赖由接口 SQL 的已知对象名及 Routine 调用递归提取，只是词法候选；动态 SQL、运行配置、Java 直接调用、触发器副作用需单独确认。
- 非 k_ 对象仅作为外部依赖登记，不构成整表迁移授权。新端不得原样搬运 interfaceSql。
- 本文件不含原始接口 SQL、行数据、密钥、生产地址或用户资料。

| 旧接口 | 分类 | 客户端静态引用 | 入口 Routine | k_ 表候选依赖 | 公共依赖（非迁移表） | 证据状态 |
|---|---|---|---|---|---|---|
| `S231202502210646` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_RegisterFirst` | `k_balance_details`、`k_user`、`k_wallet` | `id_config` | 快照目录存在；未核验线上 |
| `S231202502210647` | App | 无静态编号引用；不能据此删除 | `K_Register_GetStyles` | `k_user`、`k_user_examine_type` | — | 快照目录存在；未核验线上 |
| `S231202502210648` | App | pages/regist5/regist5.js | `K_Register_SetStyles` | `k_bill_detail`、`k_exp_detail`、`k_goldcoin_detail`、`k_system_messages`、`k_user`、`k_user_examine_images`、`k_user_relation` | `id_config` | 快照目录存在；未核验线上 |
| `S231202502210649` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_Register_SaveImage` | `k_user`、`k_user_examine_images` | `id_config` | 快照目录存在；未核验线上 |
| `S231202502210650` | App | pages/regist/regist.js | `K_Register_SmsVerify` | `k_balance_details`、`k_user`、`k_user_relation`、`k_wallet` | `g_sms`、`id_config` | 快照目录存在；未核验线上 |
| `S231202502210651` | App | 无静态编号引用；不能据此删除 | `K_Login` | `k_user` | `g_sms` | 快照目录存在；未核验线上 |
| `S231202502210652` | App | pages/index/index.js | `K_getUserInfo` | `k_balance_details`、`k_config`、`k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_conversations_temp`、`k_coupon`、`k_diamond_detail`、`k_goldcoin_detail`、`k_stored_wine`、`k_system_messages`、`k_user`、`k_user_relation`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202502220653` | App | 无静态编号引用；不能据此删除 | `K_CheckQRCode` | `k_invitation_code` | — | 快照目录存在；未核验线上 |
| `S231202503070654` | App | 无静态编号引用；不能据此删除 | `K_getUserQRCode` | `k_user` | — | 快照目录存在；未核验线上 |
| `S231202503070655` | App | 无静态编号引用；不能据此删除 | `K_getUserInfoByCode` | `k_user` | — | 快照目录存在；未核验线上 |
| `S231202503070656` | App | pages/createfriendinfo/createfriendinfo.js | `K_AddFriends` | `k_conversations`、`k_conversations_blacklist`、`k_conversations_temp`、`k_user` | `id_config` | 快照目录存在；未核验线上 |
| `S231202503070657` | App | pages/index/index.js | `K_GetConversationsList` | `k_config`、`k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_conversations_temp`、`k_coupon`、`k_stand_order`、`k_stored_wine`、`k_system_messages`、`k_user`、`k_user_setup` | — | 快照目录存在；未核验线上 |
| `S231202503100658` | App | pages/index/index.js | `K_getHomeInfo` | `k_ad_info`、`k_config`、`k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_conversations_temp`、`k_coupon`、`k_diamond_detail`、`k_goldcoin_detail`、`k_level_config`、`k_stored_wine`、`k_system_messages`、`k_user`、`k_user_relation` | `software_update` | 快照目录存在；未核验线上 |
| `S231202503110659` | App | 无静态编号引用；不能据此删除 | `K_GetDrinksAccessList` | `k_config`、`k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_conversations_temp`、`k_coupon`、`k_drinks_access_log`、`k_stored_wine`、`k_system_messages` | — | 快照目录存在；未核验线上 |
| `S231202503110660` | App | pages/getWine/getWine.js<br>pages/savecode/savecode.js | `K_GetStorageDetail` | `k_goods`、`k_items_goods`、`k_stored_items`、`k_stored_wine`、`k_user`、`k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202503110661` | App | pages/chat/chat.js | `K_GetMessageListByConversationsId` | `k_config`、`k_conversations`、`k_conversations_group_temp`、`k_conversations_messages`、`k_goldcoin_detail`、`k_user`、`k_user_setup` | — | 快照目录存在；未核验线上 |
| `S231202503110662` | App | 无静态编号引用；不能据此删除 | `K_SendMessage` | `k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_exp_detail`、`k_user`、`k_user_setup` | `id_config` | 快照目录存在；未核验线上 |
| `S231202503110663` | App | pages/index/index.js | `K_SetUserNick` | `k_user` | — | 快照目录存在；未核验线上 |
| `S231202503130664` | App | pages/Choose/Choose.js | `K_GetReserveInfo` | `k_goods`、`k_order`、`k_order_detail`、`k_order_member`、`k_stand_order`、`k_table`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202503230665` | App | 无静态编号引用；不能据此删除 | `K_GetThaliInfo` | `k_thali` | — | 快照目录存在；未核验线上 |
| `S231202503230666` | App | pages/index/index.js | `K_GetFriendList` | `k_config`、`k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_conversations_temp`、`k_coupon`、`k_stored_wine`、`k_system_messages`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202503230667` | App | 无静态编号引用；不能据此删除 | `K_GetWineClassificationInfo` | — | — | 快照目录存在；未核验线上 |
| `S231202503260668` | App | pages/newfriend/newfriend.js | `K_GetApplyConversationsList` | `k_conversations_temp`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202503260669` | App | pages/newfriendInfo/newfriendInfo.js | `K_SetApplyConversationsStatus` | `k_conversations`、`k_conversations_temp`、`k_user` | `id_config` | 快照目录存在；未核验线上 |
| `S231202503290670` | App | pages/order/order.js | `K_OneKeyToSeat` | `k_goods`、`k_goods_batch`、`k_goods_detail`、`k_goods_property`、`k_order`、`k_order_detail`、`k_order_member`、`k_table`、`k_user`、`k_user_examine_images` | `id_config` | 快照目录存在；未核验线上 |
| `S231202503290671` | App | 无静态编号引用；不能据此删除 | `K_GetTicketInfo` | `k_order_member`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202503310672` | App | pages/friendinfo/friendinfo.js<br>pages/newfriendInfo/newfriendInfo.js | `K_GetOtherInfo` | `k_conversations`、`k_conversations_blacklist`、`k_user`、`k_user_setup` | — | 快照目录存在；未核验线上 |
| `S231202504060673` | App | pages/friendinfo2/friendinfo2.js<br>pages/friendinfo3/friendinfo3.js | `K_getUserAccountInfo` | `k_conversations`、`k_conversations_blacklist`、`k_user`、`k_user_setup` | — | 快照目录存在；未核验线上 |
| `S231202504060674` | App | pages/blacklist/blacklist.js<br>pages/friendinfo2/friendinfo2.js<br>pages/friendinfo3/friendinfo3.js | `K_setupUserPower` | `k_conversations`、`k_conversations_blacklist`、`k_user_setup` | `id_config` | 快照目录存在；未核验线上 |
| `S231202504070675` | App | pages/index/index.js | `K_getBoxList` | `k_config`、`k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_conversations_temp`、`k_coupon`、`k_goods`、`k_items_goods`、`k_stored_items`、`k_stored_wine`、`k_system_messages` | — | 快照目录存在；未核验线上 |
| `S231202504070676` | App | pages/savecode/savecode.js | `K_listenCode` | `k_stored_items`、`k_stored_wine` | — | 快照目录存在；未核验线上 |
| `S231202504070677` | App | pages/getWine/getWine.js | `K_getUpdateWine` | `k_stored_wine` | — | 快照目录存在；未核验线上 |
| `S231202504070678` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_getOrderPayInfo_v2` | `k_order`、`k_order_member`、`k_stand_order`、`k_table`、`k_user` | `id_config`、`t_alipay_config`、`t_bcs_config`、`t_wxpay_config` | 快照目录存在；未核验线上 |
| `S231202504070679` | App | pages/myinfo/myinfo.js | `K_myUserInfo` | `k_level_config`、`k_user`、`k_user_examine_images` | — | 快照目录存在；未核验线上 |
| `S231202504070680` | App | pages/myinfo/myinfo.js | `K_setMyUserInfo` | `k_user`、`k_user_setup` | — | 快照目录存在；未核验线上 |
| `S231202504070681` | App | pages/modiffypwd/modiffypwd.js | `K_modiffyPwd` | `k_user` | — | 快照目录存在；未核验线上 |
| `S231202504160682` | 服务器端使用 | pages/index/index.js<br>pages/myinfo/myinfo.js | `K_ChangeHeaderImage` | `k_user` | — | 快照目录存在；未核验线上 |
| `S231202504160683` | App | pages/blacklist/blacklist.js | `K_blacklist_List` | `k_conversations`、`k_conversations_blacklist`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202504160684` | App | pages/order2/order2.js | `K_getOrderMore` | `k_balance_details`、`k_config`、`k_diamond_detail`、`k_goldcoin_detail`、`k_items_goods`、`k_order`、`k_stored_items`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202504190685` | App | pages/index/index.js | `K_AddBelowByScan` | `k_balance_details`、`k_bill_detail`、`k_exp_detail`、`k_goldcoin_detail`、`k_stand_order_type`、`k_stored_items`、`k_stored_items_log`、`k_system_messages`、`k_user`、`k_user_examine_images`、`k_user_relation`、`k_wallet` | `id_config` | 快照目录存在；未核验线上 |
| `S231202504240686` | App | pages/manage/manage.js | `K_GetManageHome` | `k_balance_details`、`k_stored_items`、`k_user_relation`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202504240687` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_PayCallback` | `k_balance_details`、`k_bill_detail`、`k_conversations_messages`、`k_exp_detail`、`k_goldcoin_detail`、`k_goods`、`k_order_member`、`k_order_temp`、`k_stand_order`、`k_stand_order_type`、`k_stored_items`、`k_stored_items_log`、`k_system_messages`、`k_table`、`k_transaction`、`k_transaction_notify`、`k_user`、`k_user_relation`、`k_wallet` | `id_config`、`t_alipay_config`、`t_bcs_config`、`t_wxpay_config` | 快照目录存在；未核验线上 |
| `S231202504270688` | App | pages/sysmessage/sysmessage.js | `k_getMySysMsgList` | `k_system_messages` | — | 快照目录存在；未核验线上 |
| `S231202504280689` | App | pages/agencybalance/agencybalance.js<br>pages/mybalance/mybalance.js | `k_getBillList` | `k_balance_details`、`k_bill_detail`、`k_diamond_detail`、`k_goldcoin_detail`、`k_stand_order`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202504280690` | App | pages/allclient/allclient.js | `k_getAllClient` | `k_level_config`、`k_order`、`k_order_member`、`k_table`、`k_user`、`k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202504280691` | App | pages/manageclient/manageclient.js | `k_getMyClient` | `k_balance_details`、`k_level_config`、`k_order`、`k_order_member`、`k_user`、`k_user_relation`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202504290692` | App | pages/detail-pages/detail-pages.js | `k_getClientInfo` | `k_balance_details`、`k_bill_detail`、`k_conversations`、`k_conversations_messages`、`k_diamond_detail`、`k_goldcoin_detail`、`k_level_config`、`k_remark_detail`、`k_stand_order`、`k_user`、`k_user_examine_images`、`k_user_relation`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202504290693` | App | pages/detail-pages/detail-pages.js | `K_modifyUserStatus` | `k_user`、`k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202504290694` | App | pages/detail-pages/detail-pages.js | `K_SaveRemark` | `k_remark_detail` | `id_config` | 快照目录存在；未核验线上 |
| `S231202504300695` | App | pages/index/index.js | `K_SetTicketStatus` | `k_order`、`k_order_member`、`k_ticket_records`、`k_user_relation` | `id_config` | 快照目录存在；未核验线上 |
| `S231202504300696` | App | pages/detail-order/detail-order.js | `k_getBillMoreInfo` | `k_order`、`k_stand_order`、`k_table`、`k_transaction`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202504300697` | App | pages/addagency/addagency.js | `K_GetAgencyUser` | `k_user`、`k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202504300698` | App | pages/addagency/addagency.js | `K_setAgencyUser` | `k_stored_items`、`k_stored_items_log`、`k_user_relation` | `id_config` | 快照目录存在；未核验线上 |
| `S231202504300699` | App | pages/index/index.js | `K_AddDailyAttendance` | `k_bill_detail`、`k_exp_detail`、`k_goldcoin_detail`、`k_sign_qrcode`、`k_system_messages`、`k_user` | `id_config` | 快照目录存在；未核验线上 |
| `S231202504300700` | App | pages/withdrawal/withdrawal.js | `K_AddOrEditBankCard` | `k_bank_card` | `id_config` | 快照目录存在；未核验线上 |
| `S231202504300701` | App | 无静态编号引用；不能据此删除 | `K_DeleteBankCard` | `k_bank_card` | — | 快照目录存在；未核验线上 |
| `S231202504300702` | App | pages/withdrawal/withdrawal.js | `K_GetBankCardList` | `k_balance_details`、`k_bank_card`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202504300703` | App | pages/withdrawal/withdrawal.js | `K_AddWithdrawalOrder` | `k_balance_details`、`k_bank_card`、`k_bill_detail`、`k_stand_order_type`、`k_system_messages`、`k_user`、`k_wallet`、`k_withdrawal` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505010704` | App | pages/send-goldCoin/send-goldCoin.js<br>pages/send-redpacket/send-redpacket.js | `k_getBlanceInfo` | `k_balance_details`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202505010705` | App | pages/send-goldCoin/send-goldCoin.js | `k_sendGoldcoin` | `k_bill_detail`、`k_conversations_messages`、`k_goldcoin_detail`、`k_system_messages`、`k_user` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505100706` | App | pages/index/index.js | `K_SetTicketOut` | `k_exp_detail`、`k_order`、`k_order_member`、`k_ticket_records`、`k_user` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505110707` | App | pages/Choose2/Choose2.js | `K_GetReserveInfoTwo` | `k_balance_details`、`k_config`、`k_goods`、`k_order`、`k_order_detail`、`k_order_member`、`k_table`、`k_user`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202505110708` | App | pages/vip-order/vip-order.js | `K_GetCanSelectData` | `k_balance_details`、`k_config`、`k_diamond_detail`、`k_goldcoin_detail`、`k_goods`、`k_goods_detail`、`k_items_goods`、`k_order`、`k_stored_items`、`k_table`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202505110709` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_CreateToSeat` | `k_goods`、`k_table` | `id_config`、`t_alipay_config`、`t_bcs_config`、`t_wxpay_config` | 快照目录存在；未核验线上 |
| `S231202505130710` | App | 无静态编号引用；不能据此删除 | `K_CancelOrder` | `k_order_member` | — | 快照目录存在；未核验线上 |
| `S231202505130711` | App | pages/seat-manage/seat-manage.js | `k_getDate` | `k_order`、`k_order_member`、`k_stand_order`、`k_table`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202505150712` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_refundOrderMoney` | `k_order`、`k_order_member`、`k_refund_transaction`、`k_stand_order`、`k_transaction` | `id_config`、`t_alipay_config`、`t_bcs_config`、`t_wxpay_config` | 快照目录存在；未核验线上 |
| `S231202505150713` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_SaveRefundNotify` | `k_balance_details`、`k_bill_detail`、`k_goldcoin_detail`、`k_order_member`、`k_refund_transaction`、`k_stand_order`、`k_stand_order_type`、`k_stored_items`、`k_stored_items_log`、`k_system_messages`、`k_user`、`k_wallet` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505150714` | App | pages/order-manage/order-manage.js | `k_getOrderInfo` | `k_balance_details`、`k_config`、`k_goods`、`k_goods_detail`、`k_order`、`k_order_detail`、`k_order_member`、`k_stand_order`、`k_user`、`k_user_relation`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202505150715` | App | pages/order-manage/order-manage.js | `k_setOrderInfo` | `k_balance_details`、`k_bill_detail`、`k_order`、`k_order_member`、`k_stand_order`、`k_stand_order_type`、`k_system_messages`、`k_user`、`k_user_relation`、`k_wallet` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505150716` | App | pages/order-manage/order-manage.js | `k_setGoodsBill` | `k_order_detail` | — | 快照目录存在；未核验线上 |
| `S231202505160717` | App | pages/select-chat/select-chat.js | `k_getshareFriend` | `k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202505160718` | App | pages/select-chat/select-chat.js | `k_sendShareMessage` | `k_config`、`k_conversations_messages` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505160719` | App | pages/chat/chat.js | `k_getSortOrderInfo` | `k_goods`、`k_order`、`k_order_detail`、`k_order_member`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202505170720` | App | pages/index/index.js | `k_getGiftsList` | `k_goods_classification`、`k_virtual_goods` | — | 快照目录存在；未核验线上 |
| `S231202505170721` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_GetBuyGoldCionPayInfo` | — | `id_config`、`t_alipay_config`、`t_bcs_config`、`t_wxpay_config` | 快照目录存在；未核验线上 |
| `S231202505170722` | App | pages/chat/chat.js | `k_buyGiftToFriend` | `k_bill_detail`、`k_conversations`、`k_conversations_messages`、`k_goldcoin_detail`、`k_system_messages`、`k_user`、`k_virtual_goods`、`k_virtual_goods_log` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505170723` | App | pages/setup/setup.js | `k_setSetup` | `k_config` | — | 快照目录存在；未核验线上 |
| `S231202505180724` | App | pages/detail-pages/detail-pages.js | `K_AdminRecharge` | `k_balance_details`、`k_bill_detail`、`k_diamond_detail`、`k_goldcoin_detail`、`k_stored_items`、`k_stored_items_log`、`k_system_messages`、`k_user`、`k_user_relation`、`k_wallet` | `id_config` | 快照目录存在；未核验线上 |
| `S231202505180725` | App | pages/setup/setup.js | `K_GetConfigSetup` | `k_config`、`k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202505310726` | App | pages/del_user_account/del_user_account.js | `K_LogoffUserAccount` | `k_user` | — | 快照目录存在；未核验线上 |
| `S231202506010727` | App | pages/index/index.wxml | `K_SetingList` | `k_user`、`k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202506010728` | App | pages/bind_account/bind_account.js | `K_BindList` | `k_user`、`k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202506010729` | App | pages/bind_account/bind_account.js | `k_BindAgency` | `k_user_relation` | — | 快照目录存在；未核验线上 |
| `S231202506020730` | App | pages/edit_info/edit_info.js | `k_getAdList` | `k_ad_info`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202506030731` | App | pages/text_editor/text_editor.js | `k_getAdContent` | `k_ad_info`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202506040732` | App | pages/text_editor/text_editor.js | `K_saveAD` | `k_ad_info` | `id_config` | 快照目录存在；未核验线上 |
| `S231202506050733` | App | pages/edit_info/edit_info.js | `K_saveIsTop` | `k_ad_info` | — | 快照目录存在；未核验线上 |
| `S231202506050734` | App | pages/shoping/shoping.js | `K_getGoodsList` | `k_goods`、`k_goods_classification`、`k_order`、`k_order_detail`、`k_stand_order`、`k_table`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202506060735` | 服务器端使用 | 无静态编号引用；不能据此删除 | `K_GetBuyGoodsPayInfo` | `k_order`、`k_table` | `id_config`、`t_alipay_config`、`t_bcs_config`、`t_wxpay_config` | 快照目录存在；未核验线上 |
| `S231202506080736` | App | pages/shoping2/shoping2.js | `K_GetMyMoney` | `k_balance_details`、`k_diamond_detail`、`k_goldcoin_detail`、`k_items_goods`、`k_stored_items`、`k_wallet` | — | 快照目录存在；未核验线上 |
| `S231202506100737` | App | pages/chat_more/chat_more.js<br>pages/group_manage_setup/group_manage_setup.js | `K_getConversationsInfo` | `k_conversations`、`k_user`、`k_user_setup` | — | 快照目录存在；未核验线上 |
| `S231202506100738` | App | pages/chat_more/chat_more.js<br>pages/group_manage_setup/group_manage_setup.js<br>pages/group_modify_name/group_modify_name.js<br>pages/group_notice/group_notice.js<br>pages/index/index.js | `K_setConversationsInfo` | `k_conversations`、`k_conversations_group_temp`、`k_user_setup` | — | 快照目录存在；未核验线上 |
| `S231202506100739` | App | components/work-comments/index.js<br>pages/chat_more_select/chat_more_select.js<br>releaseSystem/pages/createWorks/createWorks.js | `K_getAddressBook` | `k_conversations`、`k_conversations_blacklist`、`k_conversations_messages`、`k_user` | — | 快照目录存在；未核验线上 |
| `S231202506110740` | App | pages/chat_more/chat_more.js<br>pages/chat_more_select/chat_more_select.js<br>pages/index/index.js | `k_createGroupConversations` | `k_conversations`、`k_conversations_group_temp`、`k_conversations_messages`、`k_user`、`k_user_setup` | `id_config` | 快照目录存在；未核验线上 |
| `S231202506210741` | 服务器端使用 | 无静态编号引用；不能据此删除 | `k_forwardMessage` | `k_conversations_messages` | `id_config` | 快照目录存在；未核验线上 |
| `S231202506210742` | App | pages/chat/chat.js | `k_setMessageCollect` | `k_conversations_messages_collect` | `id_config` | 快照目录存在；未核验线上 |
| `S231202506270743` | App | pages/index/index.js<br>pages/userInfo/userInfo.js | `K_getNewUserInfo` | `k_conversations`、`k_division`、`k_level_config`、`k_user`、`k_user_examine_images`、`k_user_follow`、`k_user_like_praise_collect`、`k_user_relation`、`k_user_setup`、`k_user_works`、`k_user_works_files` | — | 快照目录存在；未核验线上 |
| `S231202506290744` | App | components/video-feed-player/index.js<br>pages/userInfo/userInfo.js | `K_setFollow` | `k_user`、`k_user_follow`、`k_user_setup` | `id_config` | 快照目录存在；未核验线上 |
| `S231202506290745` | App | pages/userInfo/userInfo.js | `K_setConversationsInfoV2` | `k_conversations`、`k_conversations_blacklist`、`k_user_follow`、`k_user_setup` | `id_config` | 快照目录存在；未核验线上 |
| `S231202507050746` | App | 无静态编号引用；不能据此删除 | `K_set_Like_collect` | `k_user_like_praise_collect` | `id_config` | 快照目录存在；未核验线上 |
| `S231202507180756` | App | 无静态编号引用；不能据此删除 | `K_createWorks` | `k_subject`、`k_user_works`、`k_user_works_files` | `id_config` | 快照目录存在；未核验线上 |
| `S231202507180757` | App | releaseSystem/pages/createWorks/createWorks.js | `k_getWorksPageInfo` | `k_subject`、`k_user_works` | — | 快照目录存在；未核验线上 |
| `S231202508300801` | App（后续脚本） | pages/group_manage_members/group_manage_members.js | `K_GroupManageList` | 见群聊增量脚本；未混入旧快照依赖 | — | 仅确认脚本存在，未确认实迁 |
| `S231202508300802` | App（后续脚本） | pages/chat/chat.js<br>pages/group_manage_members/group_manage_members.js<br>pages/group_manage_setup/group_manage_setup.js | `K_GroupManageAction` | 见群聊增量脚本；未混入旧快照依赖 | — | 仅确认脚本存在，未确认实迁 |
| `S231202508300803` | App（后续脚本） | pages/chat_more_select/chat_more_select.js | `K_GroupCandidateList` | 见群聊增量脚本；未混入旧快照依赖 | — | 仅确认脚本存在，未确认实迁 |
