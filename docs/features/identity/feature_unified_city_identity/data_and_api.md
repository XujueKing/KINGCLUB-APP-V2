# 同城统一账号数据模型

## 核心标识

```text
userAccount       统一平台账号，格式 U + 数字
sourceAppCode     首次创建来源：property / kingclub
legacyUserAccount 旧 KingClub 账号，仅用于迁移映射
```

不新增 `personId`。物业和 KingClub 对同一个用户直接保存相同的 `userAccount`。

## 权威库关系

```text
userAccount
  1 -> N userLoginIdentity
  1 -> N userKyc
  1 -> N userAccountMerge audit

userAccount
  1 -> 0..1 property membership
  1 -> 0..1 kingclubMember（位于 KingClub 独立库）
```

## 统一账号查询/创建

- 输入必须来自已经验证的手机号或其他身份断言。
- 权威库按活动身份唯一键加锁查询。
- 已存在时返回原 `U...`；不存在时使用统一发号 Routine 创建。
- 幂等键相同的重试必须返回同一账号。
- 身份已绑定其他账号或 KYC 冲突时，不自动合并，进入人工处理。

## 实名信息

- `anonymous`：未提供或未验证实名信息，只记录真实状态。
- `pending`：已提交待核验，保存来源、目的和受控引用。
- `verified`：核验完成，保存提供方、时间、有效期和最小必要摘要。
- 姓名、证件号等原值按字段加密；检索只使用受控 HMAC 指纹。
- 原始证件图片、人脸材料不作为普通占位数据复制。

## App 业务隔离

统一 `userAccount` 不代表权限统一。物业和 KingClub 必须分别检查自己的成员表、角色、对象归属和业务状态。
