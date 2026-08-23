# 同城统一身份数据模型

## 核心标识

```text
personId          自然人全局 ID，不直接暴露给客户端
userAccount       平台登录账号
appCode           产品标识：property / kingclub
appMembershipId   某 App 内的成员 ID
legacyUserAccount 旧系统账号，仅用于映射
```

## 建议关系

```text
person
  1 -> N userAccount
  1 -> N appMembership

userAccount
  1 -> N userLoginIdentity
  1 -> N authSession

appMembership
  1 -> 1 appProfile
  1 -> N appRole / appPermission
```

## ID 要求

- `personId` 必须跨独立数据库全局唯一，不能依赖两个数据库各自从相同序列起步。
- 具体采用 UUIDv7、ULID 或中央 ID 服务属于待技术决策。
- 外部 API 默认返回 `appMembershipId` 或业务资源 ID，不返回内部 `personId`。

## 冲突处理

- 同手机号不自动等于同一自然人。
- 微信 OpenID 必须结合 AppID；跨 App 优先使用 UnionID 并仍需验证授权关系。
- 实名材料只保存受控哈希、加密值和核验来源，不在业务表复制明文。
- 账号合并必须保留来源、操作者、时间、原因、前后映射和回滚限制。

