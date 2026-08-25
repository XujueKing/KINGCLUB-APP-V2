# 设置与账号安全旧版审计

- 文档状态：`Approved for Development`
- 审计基线：`KingClub-app / master / 505d222 / 1.1.37`

| 旧来源 | 风险 | V2 处理 |
|---|---|---|
| `setting` | superID/codeID 与 URL 动态控制路由 | 固定 allowlist + 类型化 RouteIntent |
| `setup` | 任意配置项与值类型由服务端下发 | 仅批准的本地偏好键 |
| 退出登录 | 以删本地缓存为主 | 远端撤销 + 本地原子清理 + reset |
| `modiffypwd` | userAccount/mobile 在路由，MD5 派生 PIN | 会话身份、重新认证、现代服务端凭据 |
| `del_user_account` | 一次确认即永久请求 | preflight、重新认证、幂等与对账 |
| `about/aggreement` | 版本/备案/正文硬编码且品牌不一致 | 构建元数据 + 权威文档目录 |

旧页面只作为任务线索，不复用动态菜单、MD5、成功页参数或法律正文。
