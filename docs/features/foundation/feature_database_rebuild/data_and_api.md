# 数据模型与接口影响

## 第一批建议复用的公版表

- `userAccount`
- `userLoginIdentity`
- `userProfile`
- `userKyc` / `userKycDocument`
- `userApiKey`
- `authSession`
- `platformAuditLog`（实际表名以 migration 为准）

## 第一批建议新增的 KingClub 数据

| 概念 | 用途 | 状态 |
|---|---|---|
| appMembership | 用户在 KingClub V2 的成员状态和加入时间 | 当前建议 |
| kingclubProfile | KingClub 内昵称、头像和业务资料 | 当前建议 |
| legacyIdentityMap | 旧 `k_user.userAccount` 到新身份/App 用户映射 | 当前建议 |
| personIdentityMap | 各 App 账号到全局自然人 `personId` 的映射 | 当前建议 |
| loginChallenge | 短信挑战哈希、TTL、尝试次数和消费状态 | 待决定放 MySQL 或 Redis+审计 |
| consentRecord | 协议版本、同意时间和目的 | 当前建议 |
| migrationRun / migrationError | 迁移批次、校验和异常 | 当前建议 |

## 关键映射原则

- 旧 `k_user.userAccount` 保留为 `legacyUserAccount`，不直接当新主键。
- `personId` 使用跨数据库不会碰撞的全局 ID；各 App 的 `userAccount/appMembership` 可独立演进。
- 手机号规范化后保存受控哈希和加密值，不保留可查询明文副本。
- 旧身份证、人脸材料先确定合法用途和保留期，默认不复制到开发/测试库。
- `userStatus` 拆为账户状态、KYC 状态和 KingClub 成员审核状态。
- `wsStatus` 不迁移；在线状态由 WebSocket/Redis 实时计算。
- `registrationId` 迁入设备/推送绑定，不放在用户主表。

## 面向未来统一身份的边界

```text
personId                     同城自然人全局标识
  |-- property membership   物业 App 成员与业务权限
  `-- kingclub membership   KingClub 成员与业务权限
```

默认可统一：自然人映射、登录身份、账号安全状态和必要的实名结果摘要。

默认不统一：App 昵称头像、会员资格、社交可见性、钱包、金币、订单、门店角色和代理权限。任何跨 App 共享都需要目的、授权和可见性评审。

## Routine 契约

新 Routine 统一接收一个 JSON envelope：

```json
{
  "params": {},
  "auth": {
    "userAccount": "server injected",
    "sessionId": "server injected",
    "businessLine": "kingclub"
  },
  "request": {
    "requestId": "server injected",
    "traceId": "server injected"
  }
}
```

客户端不得提交或覆盖 `auth` 与 `request` 可信字段。
