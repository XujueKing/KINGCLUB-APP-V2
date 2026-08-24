# 关系控制

- Scope ID：`KC-F-018`
- 文档状态：`Approved for Development`
- 所属业务域：`social`
- M0 范围：`In Release Scope`
- 设计版本：`Relationship Controls v1`
- 最后更新：2026-08-25

## 目标与用户价值

让会员管理自己的好友备注、内容可见性、好友删除和黑名单，并明确每项操作对关系和消息的影响。

## 已确认事实

- 旧 `friendinfo2` 可保存备注名、电话和描述，更新依赖数字 `indexNum`。
- 旧 `friendinfo3` 混合“仅聊天”、内容可见性、拉黑和删除；没有充分确认或竞态表达。
- 旧黑名单列表使用同一个共享开关状态，头像 URL 由永久账号拼接，解除操作仍依赖数字索引。
- 消息置顶、免打扰和删除会话属于 messaging，不属于好友关系权限。

## 用户已确认方案

- 好友备注只保存私有备注名（0～24字）和私有说明（0～120字）；本期移除私人电话号码字段，不申请联系人权限。
- 关系权限保留 `standard/messagesOnly`、不让对方看我的内容、不看对方内容、拉黑和删除好友。
- 拉黑是强操作：立即终止好友关系、取消双方待处理申请并禁止互发消息；解除拉黑不会自动恢复好友。
- 删除好友只终止好友关系，不自动拉黑；历史会话如何保留由单聊详情页另行确认。
- 黑名单页只列被自己拉黑的用户，解除拉黑必须二次确认。

## 页面与文档

- [KC-P-019 好友备注页](pages/page_friend_remark/README.md) — `Approved for Development`
- [KC-P-020 关系权限页](pages/page_relationship_permissions/README.md) — `Approved for Development`
- [KC-P-021 黑名单页](pages/page_blacklist/README.md) — `Approved for Development`
- [旧版审计](legacy_audit.md)
- [状态与导航](flow_and_navigation.md)
- [数据与 Fake 契约](data_and_api.md)
- [Mock 场景](mock_scenarios.md)
- [功能验收](acceptance.md)

## 本期不包含

- 手机号备注、系统通讯录写入、好友标签/分组、关注/粉丝管理。
- 会话置顶、免打扰、聊天记录删除、举报或群权限。
- 真实关系、内容可见性或黑名单接口。

## 用户已确认决策（2026-08-25）

1. 好友备注只保留备注名与说明，删除私人电话号码字段。
2. 拉黑会终止好友关系和待处理申请、禁止消息；解除后不会自动恢复好友。
3. 删除好友不等于拉黑；消息置顶/免打扰/历史会话归单聊详情设计。

## 开发门禁

本包已通过文档准入；全部 48 页批准前不创建 Flutter UI，全局 UI Flow Approved 前不得连接真实关系接口。
