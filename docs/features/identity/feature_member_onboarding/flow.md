# 会员准入用户流程与导航

- 文档状态：`Approved for Development`

## 1. 入口

- 新用户 K102 登录成功并安全保存会话后，由 K104 + `OnboardingRepository.getSnapshot()` 决定权威步骤。
- 已登录用户冷启动时同样复核，不依据本地“完成标记”跳过步骤。
- protected Shell 遇到非 approved membership 时 reset 到当前准入步骤或 KC-P-009。

## 2. 顺序与返回

| 当前页 | 正常下一步 | 返回行为 |
|---|---|---|
| KC-P-005 | KC-P-006 | 未提交输入可确认退出到登录；已进入核验中不可重复提交 |
| KC-P-006 | KC-P-007 | 返回 KC-P-005 只读结果；替换图片需按版本保存 |
| KC-P-007 | KC-P-008 | 返回 KC-P-006，已保存 optionId 保留 |
| KC-P-008 | KC-P-009 | 返回 KC-P-007；最终提交成功后全栈 reset 状态页 |
| KC-P-009 | approved → Shell；changesRequired → 指定页 | pending/rejected 根页不能返回准入表单绕过权威状态 |

流程使用受控 `OnboardingFlowRef`，只含进程内 flowId/generation；姓名、证件号、图片、optionId 集合和审核原因不得进入 URI。

## 3. 恢复

- App 被杀后不恢复页面栈，重新 bootstrap、K104 并拉取 OnboardingSnapshot。
- 服务端已提交的资料按 snapshot 恢复完成状态；未提交的证件输入和本地图片不持久化。
- 保存偏好或图片结果未知时，先重新拉 snapshot/draftVersion，不盲目重复写入。
- session 失效优先清理敏感内存和临时媒体，再 reset 登录。

## 4. 非法跳转

- 直接打开后续步骤但前置未完成：replace 到 snapshot 指定 currentStep。
- approved 用户进入任意 onboarding 路由：reset Shell 首页。
- rejected/pending/suspended 用户进入编辑页：除非 snapshot 明确 `editableSections`，否则回 KC-P-009。
- 未登录、外部链接或推送不得打开任何准入页面。
