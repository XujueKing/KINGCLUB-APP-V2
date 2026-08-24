# 会员形象资料页状态

每个槽位独立为 `empty|picking|preview|uploading|committed|failed|rejected`；页面组合状态：

| 状态 | 说明 |
|---|---|
| `loadingSnapshot` | 获取已提交槽位和 editableSections |
| `editing` | 至少一个槽位可添加/替换 |
| `saving` | 当前槽位提交中，另一槽位可查看但不最终下一步 |
| `complete` | 两槽位 committed，允许下一步 |
| `permissionDenied` | 显示相机/相册对应恢复路径 |
| `versionConflict` | 重拉 snapshot，不覆盖远端更新 |
| `offline` | 未提交本地临时图可保留至页面生命周期，不能伪装已保存 |
| `sessionLost` | 删除临时图并 reset 登录 |

图片被拒绝必须绑定具体槽位和公开 reasonCategory。
