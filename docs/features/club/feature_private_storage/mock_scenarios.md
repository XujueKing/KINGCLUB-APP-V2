# 私人储物柜 Mock 场景

| ID | 场景 | 预期 |
|---|---|---|
| STORAGE-M01 | 存酒与物品正常 | 分类展示 |
| STORAGE-M02 | 全部为空 | 空状态 |
| STORAGE-M03 | 部分取用 | 权威剩余量 |
| STORAGE-M04 | 临近过期/已过期 | 明确状态 |
| STORAGE-M05 | 暂停/争议 | 禁止取件 |
| STORAGE-M06 | 列表/详情失败 | 可重试 |
| STORAGE-M07 | 非本人/无效引用 | 不泄漏 |
| STORAGE-M08 | 动态码正常轮换 | 原子替换 |
| STORAGE-M09 | token 过期 | 立即遮盖 |
| STORAGE-M10 | 员工核验成功 | 重读为已取 |
| STORAGE-M11 | 部分交付 | 更新剩余量 |
| STORAGE-M12 | 重放/重复核验 | 不重复扣减 |
| STORAGE-M13 | 事件迟到/结果未知 | reconcile |
| STORAGE-M14 | 后台/录屏 | 隐私遮盖 |
| STORAGE-M15 | 离线 | 无码，员工协助 |
| STORAGE-M16 | 会话失效 | 清引用并 reset |
