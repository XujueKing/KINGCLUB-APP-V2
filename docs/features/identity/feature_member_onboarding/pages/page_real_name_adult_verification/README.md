# 实名与成年核验页

- Scope ID：`KC-P-005`
- 文档状态：`Approved for Development`
- 所属功能：[会员注册、资料初始化与准入](../../README.md)
- 旧版来源：`regist2`
- 路由语义：`RealNameAdultVerificationRoute`，onboarding 分区，禁止外部直达
- 设计版本：`Onboarding Wireframe v1 / Step 1`
- 最后更新：2026-08-25

## 用户任务

了解实名用途，输入本人姓名与证件号码，通过已批准的实名/活体核验并确认已成年。客户端不自行根据证件号计算年龄。

## 入口、出口与返回

- 入口：authenticated 且 snapshot.stage=`identityRequired|identityProcessing`。
- 成功：服务端确认 `kycStatus=verified` 且成年，replace KC-P-006。
- 未成年：留在阻断状态，清理输入，不创建会员申请。
- 返回：未提交时确认退出准入并回登录安全根；processing 时不能通过返回制造第二个核验流程。
- 非法状态：按最新 snapshot replace 当前权威步骤。

## 线框

```text
[返回]                    步骤 1/4
实名与成年核验
用于确认本人身份及年满 18 周岁

姓名       [________________]
证件号码   [________________] [显示/隐藏]

[ ] 我已阅读实名信息处理说明
[查看隐私政策与处理说明]

[开始核验]
为什么需要核验？
```

## 组件与规则

- 姓名：去首尾空格、长度/字符只做友好校验，不在客户端判定真实性。
- 证件号：默认掩码，支持临时显示；不提供复制，不进入自动填充日志。
- 按钮：字段格式、告知勾选完成后可用；提交期间锁定。
- 开始核验后使用 FakeIdentityVerification；真实 SDK/网页流程后置。
- 页面状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)。

## 数据与隐私

- UI Mock 只使用合成姓名和掩码占位，不保存真实输入。
- 真实方案优先让敏感材料直达批准核验方/服务端受控通道；不得 Base64 塞入通用超级接口日志链。
- 埋点只记录 `view/start/resultCategory`，不含字段长度、生日、证件尾号或供应商原文。

## 验收

见 [acceptance.md](acceptance.md)。当前只实现合成数据与 Fake 核验 UI；不得接入真实核验。
