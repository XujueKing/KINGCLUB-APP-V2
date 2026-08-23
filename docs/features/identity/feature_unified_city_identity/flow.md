# 同城统一账号流程

## KingClub 先注册

1. KingClub 服务端验证手机号挑战。
2. 通过服务间加密接口调用物业公共身份模块。
3. 权威库按手机号身份查询账号。
4. 不存在时原子生成 `U...`，写 `userAccount`、`userLoginIdentity` 和真实 KYC 状态占位。
5. 存在时返回原 `U...`，不重复发号。
6. KingClub 独立库创建账号投影、`kingclubMember` 和独立会话。

## 用户以后注册物业

1. 物业再次验证手机号或其他登录身份。
2. 公共身份模块命中 KingClub 已建立的 `U...`。
3. 检查账号、手机号和 KYC 冲突。
4. 创建物业成员、房屋关系和物业权限。
5. 不创建新的 `userAccount`。

## 身份变更同步

1. 权威库提交账号冻结、归并、手机号变更或 KYC 摘要变更。
2. 同事务写 Outbox。
3. KingClub `identitySyncInbox` 幂等消费并校验版本。
4. 冻结/归并事件撤销 KingClub 会话并关闭 WebSocket。

## 未来抽离

1. 把公共身份表和内部接口迁移到独立身份部署。
2. 物业与 KingClub 更换内部接口地址。
3. `U... userAccount`、成员表和业务数据主键不变。
