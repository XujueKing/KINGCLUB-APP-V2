# 会员准入 Mock/Fake 场景

- 文档状态：`In Review`

| ID | 场景 | 预期 |
|---|---|---|
| ONB-M01 | 新会员正常完成五页 | pendingReview，不进入 Shell |
| ONB-M02 | 服务端核验成年且实名通过 | 进入图片页；客户端不计算年龄 |
| ONB-M03 | 未成年结论 | 阻止继续，清理敏感输入，显示稳定说明 |
| ONB-M04 | 核验取消/失败/处理中 | 可安全重试或恢复，不重复创建流程 |
| ONB-M05 | 相机/相册首次拒绝、永久拒绝 | 对应说明与设置入口；无真实权限请求 |
| ONB-M06 | 图片过大、格式错、上传失败、内容拒绝 | 槽位级错误，可替换；另一槽位不丢失 |
| ONB-M07 | 四类偏好全跳过 | 仍可提交申请 |
| ONB-M08 | 目录版本过期 | 刷新目录，保留有效 optionId |
| ONB-M09 | 最终提交结果未知 | 查询 snapshot；不得重复提交或显示假成功 |
| ONB-M10 | pending → approved 事件/刷新 | reset Shell 首页，不能返回准入页 |
| ONB-M11 | changesRequired(images/preferences) | 只开放指定步骤并重新提交 |
| ONB-M12 | rejected 可/不可重提 | 严格按 canResubmit/resubmitAfter 展示动作 |
| ONB-M13 | 任一步 session revoked | 清理敏感内存和临时媒体，reset 登录 |
| ONB-M14 | App 被杀后恢复 | bootstrap 后按权威 currentStep 进入，未提交 PII 不恢复 |
| ONB-M15 | snapshot/draftVersion 冲突 | 拉取新快照，避免覆盖另一设备/迟到结果 |

所有样例使用合成姓名、掩码证件占位和仓库内非真人测试图，不使用真实个人数据。
